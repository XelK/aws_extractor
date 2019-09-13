provider "aws" {
  profile   =   "aws_extractor"
  region    =   "eu-west-2" #var.region
}


resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  #instance_tenancy = "dedicated"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  enable_classiclink = "false"
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public-1" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  tags = {
      Name = "public"
  }
}

resource "aws_subnet" "private-1" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.100.0/24"
  map_public_ip_on_launch = "false"
  #availability_zone = "${aws_subnet.public-1.vpc_id}"
  tags = {
      Name = "private"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
      Name = "internet-gateway"
  }
  
}

resource "aws_route_table" "rt1" {
  vpc_id = "${aws_vpc.main.id}"
  route{
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
      Name = "Default"
  }
}

resource "aws_route_table_association" "association-subnet" {
  subnet_id = "${aws_subnet.public-1.id}"
  route_table_id = "${aws_route_table.rt1.id}"
  
}

resource "aws_instance" "aws_extractor" {
  ami           = "ami-077a5b1762a2dde35"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.websg.id}","${aws_security_group.ssh.id}"]
  subnet_id = "${aws_subnet.public-1.id}"
  key_name = "${aws_key_pair.myawskeypair.key_name}"
  
  user_data = <<-EOF
  #!/bin/bash
  echo "hello, world" > index.html
  nohup busybox httpd -f -p 8080 &
  EOF

  lifecycle {
    create_before_destroy = true
  }

 tags = {
  Name = "aws_extractor"
 }
}

resource "aws_lb_target_group" "front_end" {
  name     = "front-end"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "front_end" {
  target_group_arn = "${aws_lb_target_group.front_end.arn}"
  target_id        = "${aws_instance.aws_extractor.id}"
  port             = 8080
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.alb.arn}"
  port              = "8080"
  protocol          = "HTTP"

  default_action{
    type            = "forward"
    target_group_arn = "${aws_lb_target_group.front_end.arn}"
  }
  
}


resource "aws_security_group" "lb_sg" {
  name = "security_group_for_lb_sg"
  vpc_id = "${aws_vpc.main.id}"
  ingress{
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create application load balancer
resource "aws_lb" "alb" {
  name               = "aws-terraform-alb"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.public-1.id}","${aws_subnet.private-1.id}"]

    tags = {
    Environment = "production"
  }
}


resource "aws_key_pair" "myawskeypair" {
    key_name = "myawskeypair"
    public_key = "${file("awskey.pub")}"
  
}

resource "aws_security_group" "websg" {
  name = "security_group_for_web_server"
  vpc_id = "${aws_vpc.main.id}"
  ingress{
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      #cidr_blocks = ["0.0.0.0/0"]
      security_groups = ["${aws_security_group.lb_sg.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ssh" {
  name = "security_group_for_ssh"
  vpc_id = "${aws_vpc.main.id}"
  ingress{
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["2.230.X.X/32"]  # my  ip
  }
  
  lifecycle {
    create_before_destroy = true
  }
}


output "vpc-id" {
  value = "${aws_vpc.main.id}"
}
output "vpc-publicsubnet" {
  value = "${aws_subnet.public-1.cidr_block}"
}
output "vpc-publicsubnet-id" {
  value = "${aws_subnet.public-1.id}"
}
output "vpc-privatesubnet" {
  value = "${aws_subnet.private-1.cidr_block}"
}
output "vpc-privatesubnet-id" {
  value = "${aws_subnet.private-1.id}"
}
output "public_ip" {
  value = "${aws_instance.aws_extractor.public_ip}"
}
output "lb_public_dns" {
  value = "${aws_lb.alb.dns_name}"
}

#   provisioner "local-exec"{
#       command = "echo ${aws_instance.aws_extractor.public_ip} > ip_address.txt"
#   }
# }
# resource "aws_eip" "ip" {
#   vpc = true
#   instance = aws_instance.aws_extractor.id
# }

# output "ip" {
#   value = aws_eip.ip.public_ip
# }


