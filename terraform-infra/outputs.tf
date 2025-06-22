output "jenkins_url" {
  value = "http://${aws_instance.jenkins_master.public_ip}:8080"
}

output "ansible_ip" {
  value = "aws_instance.ansible.public_ip"
}

output "monitoring_url" {
  value = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name ${aws_eks_cluster.devops_cluster.name}"
}

