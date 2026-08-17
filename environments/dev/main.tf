resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "myapp-vpc"
        Environment = "dev"
    }
}

resource "aws_subnet" "this" {
    for_each = var.subnets
    vpc_id = aws_vpc.main.id
    cidr_block = each.value.cidr_block
    availability_zone = each.value.availability_zone
    map_public_ip_on_launch = each.value.public
    tags = {
        Name = "myapp-${each.key}"
        Environment = "dev"

    }
}


resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "myapp-igw"
        Environment = "dev"
    }
}
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        Name = "myapp-public-rt"
        Environment = "dev"
    }

}

resource "aws_route_table_association" "public_1a" {
    subnet_id = aws_subnet.this["public_1a"].id
    route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_1b" {
    subnet_id = aws_subnet.this["public_1b"].id
    route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
    name = "myapp-alb-sg"
    description = "allow http/https public"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "Http from internet"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "myapp-alb-sg"
        Environment = "dev"
    }
}
resource "aws_security_group" "web" {
    name = "myapp-web-sg"
    description = "web tier - Allow only from ALB"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "http from alb to web"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
    }
    ingress {
        description = "ssh into public server"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "myapp-web-sg"
        Environment = "dev"
    }
}

data "aws_ami" "amazon_linux" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["al2023-ami-*-x86_64"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}
/*
resource "aws_instance" "web" {
    ami = data.aws_ami.amazon_linux.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.this["public_1a"].id
    vpc_security_group_ids = [aws_security_group.web.id]
    key_name = "myapp-key"

    user_data = <<-EOF
                #!/bin/bash
                dnf install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
                EOF

    tags = {
        Name = "myapp-web-server"
        Environment = "dev"
    }
}
*/
resource "aws_lb" "main" {
    name = "myapp-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb.id]
    subnets = [aws_subnet.this["public_1a"].id, aws_subnet.this["public_1b"].id]
    tags = {
        Name = "myapp-alb"
        Environment = "dev"
    }
}

resource "aws_lb_target_group" "web" {
    name = "my-app-web-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id

    health_check {
        path = "/"
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
        interval = 10
    }

    tags = {
        Name = "myapp-web-tg"
        Environment = "dev"
    }

}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.main.arn
    port = 80
    protocol = "HTTP"

    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
/*
resource "aws_lb_target_group_attachment" "web" {
    target_group_arn = aws_lb_target_group.web.arn
    target_id = aws_instance.web.id
    port = 80
}*/

resource "aws_launch_template" "web" {
    name_prefix = "myapp-web-lt-"
    image_id = data.aws_ami.amazon_linux.id
    instance_type = "t2.micro"
    key_name = "myapp-key"
    vpc_security_group_ids = [aws_security_group.web.id]
    
    user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
    )
    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "myapp-web-asg"
            Environment = "dev"
        }
    }
    
}
resource "aws_autoscaling_group" "web" {
    name = "myapp-web-asg"
    min_size = 2
    max_size = 4
    desired_capacity = 2
    vpc_zone_identifier = [aws_subnet.this["public_1a"].id, aws_subnet.this["public_1b"].id]
    target_group_arns = [aws_lb_target_group.web.arn]
    health_check_type = "ELB"
    health_check_grace_period = 60

    launch_template {
        id = aws_launch_template.web.id
        version = "$Latest"
    }
    tag {
        key = "Environment"
        value = "dev"
        propagate_at_launch = true
    }
}