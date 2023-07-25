# Step - CREATE VPC

resource "aws_vpc" "terraform_demo" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "terraform_demo"
    }
}

# Step - CREATE Public Subnet 
# (since the application doesn't have any database or any other confidental resource, i'm not creating any private subnet or NAT gateway)

resource "aws_subnet" "terraform_demo_public_subnet"{

    vpc_id = aws_vpc.terraform_demo.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "terraform_demo_public_subnet"
    }

}

# Step - CREATE Internet Gateway inside vpc

resource "aws_internet_gateway" "terraform_demo_internet_gateway"{

    vpc_id = aws_vpc.terraform_demo.id

    tags = {
        Name = "terraform_demo_internet_gateway"
    }
}

# Step - CREATE route

resource "aws_route" "terraform_demo_public_subnet_internet_gateway" {
  route_table_id         = aws_vpc.terraform_demo.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.terraform_demo_internet_gateway.id
}

# Step - CREATE ami for EC2 instance with user-name ubuntu

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] 
}

# Step - CREATE EC2 instance

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.terraform_demo_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.terraform_demo_security_group.id]
  availability_zone = "us-east-1a"
  key_name = "terraform_demo_key"

  tags = {
    Name = "HelloWorld"
  }
}

# Step - CREATE security group 

resource "aws_security_group" "terraform_demo_security_group" {
    name        = "terraform_demo_security_group"
    description = "Allow inbound traffic"
    vpc_id      = aws_vpc.terraform_demo.id

    ingress {
        description = "Http"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }


    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "terraform_demo_security_group"
    }
}


# Step - CREATE public and private keys using RSA algorithm

resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Step - EXTRACT public keys

resource "aws_key_pair" "terraform_demo_key" {
  key_name   = "terraform_demo_key"
  public_key = tls_private_key.rsa_key.public_key_openssh
}

# Step - STORE private key in your local machine

resource "local_file" "terraform_demo_private_key" {
  content  = tls_private_key.rsa_key.private_key_pem
  filename = "key.pem"
}

# Step - GET public ip of ec2 instance to ssh using private key

output "ec2_instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value = aws_instance.web.public_ip
}