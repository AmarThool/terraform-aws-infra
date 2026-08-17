variable "subnets" {
    description = "Map of subnet to create"
    type = map(object({
        cidr_block = string
        availability_zone = string
        public = bool
    }))
    default = {
        public_1a = {
            cidr_block = "10.0.1.0/24"
            availability_zone = "us-east-1a"
            public = true
        }
        private_1a = {
            cidr_block = "10.0.2.0/24"
            availability_zone = "us-east-1a"
            public = false
        }
        public_1b = {
            cidr_block = "10.0.3.0/24"
            availability_zone = "us-east-1b"
            public = true
        }
        private_1b = {
            cidr_block = "10.0.4.0/24"
            availability_zone = "us-east-1b"
            public = false
        }
    }

}

variable "my_ip" {
    description = "Ip address to add in ssh"
    type = string
}