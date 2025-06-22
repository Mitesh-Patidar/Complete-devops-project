resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "project6_vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "project6_igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  cidr_block              = var.public_subnets[count.index]
  vpc_id                  = aws_vpc.main_vpc.id
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "project6_public_subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "project6-public-route-table"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_rta" {
  count          = length(var.public_subnets)
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "Project6-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id    = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "nat-gateway"
  }
  
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "Project6-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "project6-route-table"
  }
}

resource "aws_route" "nat_gw_route" {
  route_table_id         = aws_route_table.private_rt.id
  nat_gateway_id         = aws_nat_gateway.nat.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_rta" {
  route_table_id = aws_route_table.private_rt.id
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_security_group" "jenkins_sg" {
  name = "jenkins-sg"
  description = "Allow ssh and jenkins UI"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
   description = "SSH"
   from_port = 22
   to_port = 22
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
   description = "Jenkins UI"
   from_port = 8080
   to_port = 8080
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
    Name = "Jenkins-sg"
  }
}

resource "aws_security_group" "ansible_sg" {
  name = "ansible-sg"
  description = "Allow SSH"
  vpc_id = aws_vpc.main_vpc.id
 
  ingress {
   from_port = 22
   to_port = 22
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
    Name = "Ansible-sg"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name = "monitoring-sg"
  description = "Allow Prometheus and Grafana access"
  vpc_id = aws_vpc.main_vpc.id
  
  ingress {
   from_port = 3000
   to_port = 3000
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
   from_port = 9090
   to_port = 9090
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
   from_port = 22
   to_port = 22
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
    Name = "Monitoring-sg"
  }
} 

resource "aws_instance" "jenkins_master" {
  ami = data.aws_ami.linux.id
  instance_type = var.instance_type
  key_name = "Miteshkey"
  security_groups = [aws_security_group.jenkins_sg.id]
  subnet_id = aws_subnet.public[0].id
  
  tags = {
    Name = "jenkins-master"
  }
}

resource "aws_instance" "jenkins_agent" {
  ami = data.aws_ami.linux.id
  instance_type = var.instance_type
  key_name = "Miteshkey"
  security_groups = [aws_security_group.jenkins_sg.id]
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "jenkins-agent"
  }
}

resource "aws_instance" "ansible" {
  ami = data.aws_ami.linux.id
  instance_type = var.instance_type
  key_name = "Miteshkey"
  security_groups = [aws_security_group.ansible_sg.id]
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "ansible-controller"
  }
}

resource "aws_instance" "monitoring" {
  ami = data.aws_ami.linux.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.public[1].id
  security_groups = [aws_security_group.monitoring_sg.id]
  key_name = "Miteshkey"

  tags = {
   Name = "monitoring"
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"
  
  assume_role_policy = jsonencode ({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { 
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "devops_cluster" {
  name = "devops-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
  }
  
  depends_on = [
   aws_iam_role_policy_attachment.eks_cluster_policy
  ]
  
  tags = {
   Name = "devops-eks"
  }
}

resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_policies" {
  count      = 3
  role       = aws_iam_role.eks_node_role.name
  policy_arn = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ][count.index]
}

resource "aws_eks_node_group" "devops_nodes" {
  cluster_name    = aws_eks_cluster.devops_cluster.name
  node_group_name = "devops-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_policies
  ]

  tags = {
    Name = "devops-nodes"
  }
}

