resource "local_file" "inventory" {
  filename   = "${path.module}/../ansible/inventory.ini"
  content    = <<-EOF
    [localhost:vars]
    endpoint=${aws_db_instance.postgres.endpoint}
    db_name=${var.database_name}
    db_user=${var.master_username}
    db_password=${var.master_password}

  EOF
  depends_on = [aws_db_instance.postgres]
}
