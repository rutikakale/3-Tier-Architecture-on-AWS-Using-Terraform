variable "region" {
  default = "ap-south-1"
}

variable "az1" {
  default = "ap-south-1a"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# tier-specific CIDRs (adjust as required)
variable "web_cidr" {
  default = "10.0.16.0/24"
}

variable "app_cidr" {
  default = "10.0.17.0/24"
}

variable "db_cidr" {
  default = "10.0.18.0/24"
}

variable "project_name" {
  default = "FCT"
}

variable "ami" {
  default = "ami-0d176f79571d18a8f"
}

variable "instance" {
  default = "t2.micro"
}

variable "key_name" {
  default = "terraform"
}

# ports
variable "app_port" {
  default = 8080
}

variable "db_port" {
  default = 3306
}
