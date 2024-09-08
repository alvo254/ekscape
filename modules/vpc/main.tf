resource "aws_vpc" "ekscape" {
  cidr_block = var.cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }

}

data "aws_availability_zones" "available_zones" {}

resource "aws_subnet" "ekscape-pub-sub" {
  vpc_id = aws_vpc.ekscape.id
  cidr_block = var.public_subnet
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block = cidrsubnet(aws_vpc.ekscape.ipv6_cidr_block, 8, 1)


  tags = {
    Name = "${var.project}- ${var.env}-public-sub-1"
  }


}

resource "aws_internet_gateway" "ekscape-ig" {
  vpc_id = aws_vpc.ekscape.id

  tags = {
    Name = ""
  }
}


resource "aws_route_table" "ekscape-rtb" {
  vpc_id = aws_vpc.ekscape.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ekscape-ig.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.ekscape-ig.id
  }
}