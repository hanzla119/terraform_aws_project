resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
  }
  resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  }

  resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  }
  resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id

  }
  resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
        }
     }
   resource "aws_route_table_association" "rta1" {
     subnet_id = aws_subnet.sub1.id
route_table_id = aws_route_table.RT.id
   }
   resource "aws_route_table_association" "rta2" {
     subnet_id = aws_subnet.sub2.id
route_table_id = aws_route_table.RT.id
   }
resource "aws_security_group" "websg" {
  name = "websg"
  description = "Allow SSH inbound traffic"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

   ingress {
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
  "Name" = "web-sg"
}
}
resource "aws_s3_bucket" "example" {
  bucket = "my-hanzla-119-unique-bucket-name-12345"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example1" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false   
  
}


resource "aws_s3_bucket_acl" "example2" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example1,
  ]
  bucket = aws_s3_bucket.example.id
  acl    = "public-read"
}
resource "aws_instance" "webserver1" {
ami = "ami-0ec10929233384c7f"
instance_type = "t3.micro"
vpc_security_group_ids = [aws_security_group.websg.id]
subnet_id = aws_subnet.sub1.id
user_data = file("userdata.sh")
}

resource "aws_instance" "webserver2" {
ami = "ami-0ec10929233384c7f"
instance_type = "t3.micro"
vpc_security_group_ids = [aws_security_group.websg.id]
subnet_id = aws_subnet.sub2.id
user_data = file("userdata1.sh")
}
#creat load balancer
resource "aws_lb" "myalb" {
    name               = "my-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.websg.id]
    subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]
   tags = {
    Name = "my-alb"
}
}
resource "aws_lb_target_group" "tg" {
    name     = "mytg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.myvpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id 
    port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id 
    port             = 80
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
  
}
output "loadbalancers" {
  
value = aws_lb.myalb.dns_name
}