output "vpc_id" {
  description = "ID of techcorp-vpc"
  value       = aws_vpc.vpc_main.id
}

output "instances" {
  description = "EC2 instance details"
  value = {
    bastion = {
      id        = aws_instance.instance_bastion.id
      public_ip = aws_eip.eip_bastion.public_ip
      ssh       = "ssh -i ${local_file.techcorp_key_private.filename} ec2-user@${aws_eip.eip_bastion.public_ip}"
    }
    db = {
      id                      = aws_instance.instance_db.id
      private_ip              = aws_instance.instance_db.private_ip
      ssh                     = "ssh -i ${local_file.techcorp_key_private.filename} -J ec2-user@${aws_eip.eip_bastion.public_ip} ec2-user@${aws_instance.instance_db.private_ip}"
      ssh_macbook_alternative = "ssh -i ${local_file.techcorp_key_private.filename} -o 'ProxyCommand=ssh -i ${local_file.techcorp_key_private.filename} -W %h:%p ec2-user@${aws_eip.eip_bastion.public_ip}' ec2-user@${aws_instance.instance_db.private_ip}"
    }
    web_1 = {
      id                      = aws_instance.instance_web_1.id
      private_ip              = aws_instance.instance_web_1.private_ip
      ssh                     = "ssh -i ${local_file.techcorp_key_private.filename} -J ec2-user@${aws_eip.eip_bastion.public_ip} ec2-user@${aws_instance.instance_web_1.private_ip}"
      ssh_macbook_alternative = "ssh -i ${local_file.techcorp_key_private.filename} -o 'ProxyCommand=ssh -i ${local_file.techcorp_key_private.filename} -W %h:%p ec2-user@${aws_eip.eip_bastion.public_ip}' ec2-user@${aws_instance.instance_web_1.private_ip}"
    }
    web_2 = {
      id                      = aws_instance.instance_web_2.id
      prvate_ip               = aws_instance.instance_web_2.private_ip
      ssh                     = "ssh -i ${local_file.techcorp_key_private.filename} -J ec2-user@${aws_eip.eip_bastion.public_ip} ec2-user@${aws_instance.instance_web_2.private_ip}"
      ssh_macbook_alternative = "ssh -i ${local_file.techcorp_key_private.filename} -o 'ProxyCommand=ssh -i ${local_file.techcorp_key_private.filename} -W %h:%p ec2-user@${aws_eip.eip_bastion.public_ip}' ec2-user@${aws_instance.instance_web_2.private_ip}"
    }
  }
}