provider "aws" {
  region = ""  # enter your region
}

#Get Ubuntu AMI ID using SSM Parameter endpoint in us-east-2
data "aws_ssm_parameter" "ubuntuAmi" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # verify available version
}

#Create and bootstrap EC2 in us-east-2
resource "aws_instance" "ec2-ubuntu-web-server" {
  ami                         = data.aws_ssm_parameter.ubuntuAmi.value
  instance_type               = "t3.micro" # verify available type
  associate_public_ip_address = true
  vpc_security_group_ids      = [""]  # enter your security group
  subnet_id                   = ""  # enter your subnet
  key_name                    = "" # enter only the name of the .pem file
  user_data = file("userdata.sh")
  tags = {
    Name = "webServer"
    backup = "multier"
  }
}

resource "null_resource" "sleep_example" {
  depends_on = [aws_instance.ec2-ubuntu-web-server]

  provisioner "remote-exec" {
    inline = [
      "echo 'Sleeping for 30 seconds...'",
      "sleep 30",  # Sleep for 30 seconds
      "echo 'Sleep completed!'"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-") # enter file name
    }
  }
}

resource "null_resource" "node_exporter" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "sudo apt-get update",
        "sudo apt-get install -y wget tar",
        "cd /tmp",
        "wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz",
        "tar xvfz node_exporter-1.10.2.linux-amd64.tar.gz",
        "sudo install -m 0755 /tmp/node_exporter-1.10.2.linux-amd64/node_exporter /usr/local/bin/node_exporter",
        "/usr/local/bin/node_exporter --version",
        "sudo useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter"
        #"sudo chmod 644 /var/www/html/website.php"  # Ensure proper permissions for the file
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }

  provisioner "file" {
    source      = "./node_exporter.service"                            # Local path of website.php
    destination = "/tmp/node_exporter.service"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"                             # Amazon Linux default user
      private_key = file("./-")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/node_exporter.service /etc/systemd/system/node_exporter.service",  
      "sudo systemctl daemon-reload", 
      "sudo systemctl enable --now node_exporter"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }
}

resource "null_resource" "enable_nginx_metrics" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example, null_resource.node_exporter]

  provisioner "file" {
    source      = "./stub_status.conf"                            # Local path of website.php
    destination = "/tmp/stub_status.conf"            # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"                             # Amazon Linux default user
      private_key = file("./-")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/stub_status.conf /etc/nginx/conf.d/stub_status.conf",
      "sudo nginx -t", 
      "sudo systemctl reload nginx"
      #"sudo chmod 644 /var/www/html/website.php"          # Ensure proper permissions for the file
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }
}

resource "null_resource" "install_nginx_exporter" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "wget https://github.com/nginx/nginx-prometheus-exporter/releases/download/v1.5.3/nginx-prometheus-exporter_1.5.3_linux_amd64.tar.gz",
      "tar -xzf nginx-prometheus-exporter_1.5.3_linux_amd64.tar.gz",
      "sudo install -m 0755 nginx-prometheus-exporter /usr/local/bin/nginx-prometheus-exporter",
      "/usr/local/bin/nginx-prometheus-exporter --version",
      "sudo useradd --system --no-create-home --shell /usr/sbin/nologin nginx_exporter"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }

  provisioner "file" {
    source      = "./nginx_exporter.service"                            # Local path of dbinfo.inc
    destination = "/tmp/nginx_exporter.service"    # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"                             # Amazon Linux default user
      private_key = file("./-")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
        "sudo mv /tmp/nginx_exporter.service /etc/systemd/system/nginx_exporter.service",
        "sudo systemctl daemon-reload", 
        "sudo systemctl enable --now nginx_exporter"
        # Ensure proper permissions for the file
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }

}

resource "null_resource" "install_prometheus" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "cd /tmp",
        "wget https://github.com/prometheus/prometheus/releases/download/v3.15.1/prometheus-3.15.1.linux-amd64.tar.gz",
        "tar -xzf prometheus-3.15.1.linux-amd64.tar.gz",
        "sudo useradd --system --no-create-home --shell /usr/sbin/nologin prometheus",
        "sudo install -m 0755 /tmp/prometheus-3.15.1.linux-amd64/prometheus /usr/bin/prometheus",
        "sudo install -m 0755 /tmp/prometheus-3.15.1.linux-amd64/promtool /usr/bin/promtool",
        "/usr/bin/prometheus --version",
        "sudo mkdir -p /etc/prometheus",
        "sudo mkdir -p /var/lib/prometheus",
        "sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus",
        "sudo cp -r /tmp/prometheus-3.15.1.linux-amd64/consoles /etc/prometheus/",
        "sudo cp -r /tmp/prometheus-3.15.1.linux-amd64/console_libraries /etc/prometheus/",
        "sudo cp /tmp/prometheus-3.15.1.linux-amd64/prometheus.yml /etc/prometheus/prometheus.yml",
        "sudo chown -R prometheus:prometheus /etc/prometheus"
        #"sudo chmod 644 /var/www/html/website.php"   # Ensure proper permissions for the file
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }

  provisioner "file" {
    source      = "./prometheus.yml"                            # Local path of website.php
    destination = "/tmp/prometheus.yml"              # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"                             # Amazon Linux default user
      private_key = file("./-")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./prometheus.service"                            # Local path of website.php
    destination = "/tmp/prometheus.service"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"                             # Amazon Linux default user
      private_key = file("./-")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
        "sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml",
        "sudo mv /tmp/prometheus.service /etc/systemd/system/prometheus.service",
        "sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml",
        "sudo systemctl daemon-reload", 
        "sudo systemctl enable --now prometheus"
        #"sudo chmod 644 /var/www/html/website.php"          # Ensure proper permissions for the file
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }
}

resource "null_resource" "install_grafana" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example, null_resource.install_prometheus, null_resource.enable_nginx_metrics]

  provisioner "remote-exec" {
    inline = [
        "sudo apt-get install -y apt-transport-https wget gnupg",
        "sudo mkdir -p /etc/apt/keyrings",
        "sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key",
        "sudo chmod 644 /etc/apt/keyrings/grafana.asc",
        "echo 'deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main' | sudo tee -a /etc/apt/sources.list.d/grafana.list",
        "sudo apt-get update",
        "sudo apt-get install -y grafana",
        "sudo systemctl enable --now grafana-server"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./-")
    }
  }
}


