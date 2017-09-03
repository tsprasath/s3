{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "Launches a Jenkins server.",
  "Parameters": {
    "InstanceType": {
      "Description": "EC2 instance type",
      "Type": "String",
      "Default": "t2.small",
      "AllowedValues": [
        "t1.micro",
        "t2.small",
        "m1.small",
        "m1.medium",
        "m1.large",
        "m1.xlarge",
        "m2.xlarge",
        "m2.2xlarge",
        "m2.4xlarge",
        "m3.xlarge",
        "m3.2xlarge",
        "c1.medium",
        "c1.xlarge",
        "cc1.4xlarge",
        "cc2.8xlarge",
        "cg1.4xlarge"
      ],
      "ConstraintDescription": "must be a valid EC2 instance type."
    },
    "SshKey": {
      "Description": "Name of an existing EC2 keypair to enable SSH access to the instances",
      "Default": "your-ssh-key",
      "Type": "AWS::EC2::KeyPair::KeyName"
    },
    "IPWhitelist": {
      "Description": "IP Address to Whitelist (your IP address followed by /32)",
      "MinLength": "9",
      "MaxLength": "18",
      "Type": "String",
      "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "ConstraintDescription": "must be a valid IP CIDR range of the form x.x.x.x/x."
    },
    "EmailAddress": {
      "Description": "What email address will receive the default Jenkins password",
      "Type": "String",
      "Default": ""
    },
    "DnsPrefix": {
      "Description": "Prefix for Jenkins' DNS record (<prefix>.<zone>)",
      "Type": "String",
      "Default": "builds"
    },
    "DnsZone": {
      "Description": "Route53-hosted zone to use for the DNS record (<prefix>.<zone>)",
      "Type": "String",
      "Default": "your-website.com"
    },
    "S3Bucket": {
      "Description": "Existing S3 bucket to use for Jenkins backups and restores",
      "Type": "String",
      "Default": "your-s3-bucket"
    },
    "S3Prefix": {
      "Description": "[Optional] Key prefix to use for Jenkins backups",
      "Type": "String",
      "Default": ""
    },
    "Subnets": {
      "Description": "List of VPC subnet IDs for the cluster",
      "Type": "List<AWS::EC2::Subnet::Id>"
    },
    "VpcId": {
      "Description": "VPC associated with the provided subnets",
      "Type": "AWS::EC2::VPC::Id"
    },
    "AdminSecurityGroup": {
      "Description": "Existing security group that should be granted administrative access to Jenkins (e.g., 'sg-123456')",
      "Default": "Primary",
      "Type": "AWS::EC2::SecurityGroup::Id"
    }
  },
  "Mappings": {
    "RegionMap": {
      "us-east-1": {
        "AMI": "ami-6869aa05"
      },
      "us-west-1": {
        "AMI": "ami-7172b611"
      },
      "us-west-2": {
        "AMI": "ami-31490d51"
      },
      "eu-west-1": {
        "AMI": "ami-f9dd458a"
      }
    }
  },
  "Resources": {
    "CloudFormationLogs": {
      "Type": "AWS::Logs::LogGroup",
      "Properties": {
        "RetentionInDays": 7
      }
    },
    "SwiftOtterJenkins": {
      "Type": "AWS::IAM::User",
      "Properties": {
        "Policies": [
          {
            "PolicyName": "S3Access",
            "PolicyDocument": {
              "Statement": [
                {
                  "Effect": "Allow",
                  "Action": "s3:*",
                  "Resource": {
                    "Fn::Join": [
                      "",
                      [
                        "arn:aws:s3:::",
                        {
                          "Ref": "S3Bucket"
                        },
                        "/*"
                      ]
                    ]
                  }
                }
              ]
            }
          },
          {
            "PolicyName": "IAMAccess",
            "PolicyDocument": {
              "Statement": [
                {
                  "Effect": "Allow",
                  "NotAction": "iam:*",
                  "Resource": "*"
                }
              ]
            }
          },
          {
            "PolicyName": "EC2Access",
            "PolicyDocument": {
              "Statement": [
                {
                  "Effect": "Allow",
                  "Action": "ec2:*",
                  "Resource": "*"
                }
              ]
            }
          }
        ]
      }
    },
    "BuildRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "Service": [
                  "ec2.amazonaws.com"
                ]
              },
              "Action": [
                "sts:AssumeRole"
              ]
            }
          ]
        },
        "Policies": [
          {
            "PolicyName": "root",
            "PolicyDocument": {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Action": "*",
                  "Resource": "*"
                }
              ]
            }
          }
        ]
      }
    },
    "RolePolicies": {
      "Type": "AWS::IAM::Policy",
      "Properties": {
        "PolicyName": "root",
        "PolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Action": "ec2:*",
              "Effect": "Allow",
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": "elasticloadbalancing:*",
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": "cloudwatch:*",
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": "autoscaling:*",
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": "s3:*",
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": [
                "iam:PassRole",
                "iam:ListInstanceProfiles",
                "ec2:*"
              ],
              "Resource": "*"
            }
          ]
        },
        "Roles": [
          {
            "Ref": "BuildRole"
          }
        ]
      }
    },
    "BuildInstanceProfile": {
      "Type": "AWS::IAM::InstanceProfile",
      "Properties": {
        "Path": "/",
        "Roles": [
          {
            "Ref": "BuildRole"
          }
        ]
      }
    },
    "HostKeys": {
      "Type": "AWS::IAM::AccessKey",
      "Properties": {
        "UserName": {
          "Ref": "SwiftOtterJenkins"
        }
      }
    },
    "ServerGroup": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "AvailabilityZones": {
          "Fn::GetAZs": ""
        },
        "LaunchConfigurationName": {
          "Ref": "LaunchConfig"
        },
        "MinSize": "1",
        "MaxSize": "1",
        "DesiredCapacity": "1",
        "LoadBalancerNames": [
          {
            "Ref": "ElasticLoadBalancer"
          }
        ]
      }
    },
    "LaunchConfig": {
      "Type": "AWS::AutoScaling::LaunchConfiguration",
      "Metadata": {
        "AWS::CloudFormation::Init": {
          "configSets": {
            "install": [
              "installConfig",
              "installApp",
              "installLogs"
            ]
          },
          "installConfig": {
            "files": {
              "/etc/cfn/cfn-hup.conf": {
                "content": {
                  "Fn::Join": [
                    "",
                    [
                      "[main]\n",
                      "stack=",
                      {
                        "Ref": "AWS::StackId"
                      },
                      "\n",
                      "region=",
                      {
                        "Ref": "AWS::Region"
                      },
                      "\n"
                    ]
                  ]
                },
                "mode": "000400",
                "owner": "root",
                "group": "root"
              },
              "/etc/cfn/hooks.d/cfn-auto-reloader.conf": {
                "content": {
                  "Fn::Join": [
                    "",
                    [
                      "[cfn-auto-reloader-hook]\n",
                      "triggers=post.update\n",
                      "path=Resources.WebServerInstance.Metadata.AWS::CloudFormation::Init\n",
                      "action=/opt/aws/bin/cfn-init -v ",
                      "         --stack ",
                      {
                        "Ref": "AWS::StackName"
                      },
                      "         --resource WebServerInstance ",
                      "         --configsets install_all ",
                      "         --region ",
                      {
                        "Ref": "AWS::Region"
                      },
                      "\n",
                      "runas=root\n"
                    ]
                  ]
                }
              }
            },
            "services": {
              "sysvinit": {
                "cfn-hup": {
                  "enabled": "true",
                  "ensureRunning": "true",
                  "files": [
                    "/etc/cfn/cfn-hup.conf",
                    "/etc/cfn/hooks.d/cfn-auto-reloader.conf"
                  ]
                }
              }
            }
          },
          "installLogs": {
            "packages": {
              "yum": {
                "awslogs": []
              }
            },
            "commands": {
              "01_create_state_directory": {
                "command": "mkdir -p /var/awslogs/state"
              }
            },
            "services": {
              "sysvinit": {
                "awslogs": {
                  "enabled": "true",
                  "ensureRunning": "true",
                  "files": [
                    "/etc/awslogs/awslogs.conf"
                  ]
                }
              }
            },
            "files": {
              "/etc/awslogs/awslogs.conf": {
                "content": {
                  "Fn::Join": [
                    "",
                    [
                      "[general]\n",
                      "state_file= /var/awslogs/state/agent-state\n",
                      "[/var/log/cloud-init.log]\n",
                      "file = /var/log/cloud-init.log\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/cloud-init.log\n",
                      "datetime_format = \n",
                      "[/var/log/cloud-init-output.log]\n",
                      "file = /var/log/cloud-init-output.log\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/cloud-init-output.log\n",
                      "datetime_format = \n",
                      "[/var/log/cfn-init.log]\n",
                      "file = /var/log/cfn-init.log\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/cfn-init.log\n",
                      "datetime_format = \n",
                      "[/var/log/cfn-hup.log]\n",
                      "file = /var/log/cfn-hup.log\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/cfn-hup.log\n",
                      "datetime_format = \n",
                      "[/var/log/cfn-wire.log]\n",
                      "file = /var/log/cfn-wire.log\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/cfn-wire.log\n",
                      "datetime_format = \n",
                      "[/var/log/httpd]\n",
                      "file = /var/log/httpd/*\n",
                      "log_group_name = ",
                      {
                        "Ref": "CloudFormationLogs"
                      },
                      "\n",
                      "log_stream_name = {instance_id}/httpd\n",
                      "datetime_format = %d/%b/%Y:%H:%M:%S\n"
                    ]
                  ]
                },
                "mode": "000444",
                "owner": "root",
                "group": "root"
              },
              "/etc/awslogs/awscli.conf": {
                "content": {
                  "Fn::Join": [
                    "",
                    [
                      "[plugins]\n",
                      "cwlogs = cwlogs\n",
                      "[default]\n",
                      "region = ",
                      {
                        "Ref": "AWS::Region"
                      },
                      "\n"
                    ]
                  ]
                },
                "mode": "000444",
                "owner": "root",
                "group": "root"
              }
            }
          },
          "installApp": {
            "packages": {
              "python": {
                "awscli": []
              },
              "yum": {
                "git-all": []
              }
            },
            "files": {
              "/etc/aws.conf": {
                "content": {
                  "Fn::Join": [
                    "\n",
                    [
                      "[default]",
                      "aws_access_key_id={{access_key}}",
                      "aws_secret_access_key={{secret_key}}"
                    ]
                  ]
                },
                "context": {
                  "access_key": {
                    "Ref": "HostKeys"
                  },
                  "secret_key": {
                    "Fn::GetAtt": [
                      "HostKeys",
                      "SecretAccessKey"
                    ]
                  }
                },
                "mode": "000700",
                "owner": "root",
                "group": "root"
              },
              "/usr/local/bin/jenkins-restore": {
                "content": {
                  "Fn::Join": [
                    "\n",
                    [
                      "#!/bin/bash -e",
                      "",
                      "USAGE=\"Usage: $0 S3_TARGET JENKINS_HOME\\n",
                      "\\n",
                      "Example:\\n",
                      "$0 s3://mybucket/jenkins/jenkins-201405011901.tar.gz /var/lib/jenkins\\n",
                      "\\n",
                      "If S3_TARGET is a directory, restore from the newest file. Make sure to include the trailing slash:\\n",
                      "$0 s3://mybucket/jenkins/ /var/lib/jenkins\"",
                      "",
                      "S3_TARGET=$1",
                      "JENKINS_HOME=$2",
                      "if [[ -z \"`echo $S3_TARGET|grep '^s3://'`\" ]]; then",
                      "    echo -e $USAGE",
                      "    exit 1",
                      "fi",
                      "",
                      "if [[ \"$S3_TARGET\" == */ ]]; then",
                      "    S3_TARGET=$S3_TARGET`aws s3 ls $S3_TARGET|tail -1|awk '{print $NF}'`",
                      "fi",
                      "",
                      "LOCAL_BACKUP=/tmp/`basename $S3_TARGET`",
                      "aws s3 cp $S3_TARGET $LOCAL_BACKUP",
                      "",
                      "rm -rf $JENKINS_HOME",
                      "#if [[ -d \"$JENKINS_HOME\" ]]; then",
                      "#    read -p \"Delete existing $JENKINS_HOME? (y/n) \" -n 1 -r",
                      "#    echo",
                      "#    if [[ $REPLY =~ ^[Yy]$ ]]; then",
                      "#        rm -rf $JENKINS_HOME",
                      "#    else",
                      "#        echo \"Bailing out\"",
                      "#        exit 1",
                      "#    fi",
                      "#fi",
                      "",
                      "mkdir -p $JENKINS_HOME",
                      "tar zxf $LOCAL_BACKUP -C $JENKINS_HOME",
                      "rm -f $LOCAL_BACKUP"
                    ]
                  ]
                },
                "mode": "000755",
                "owner": "root",
                "group": "root"
              },
              "/usr/local/bin/jenkins-backup": {
                "content": {
                  "Fn::Join": [
                    "\n",
                    [
                      "#!/bin/bash -e",
                      "",
                      "USAGE=\"Usage: $0 JENKINS_HOME S3_TARGET\\n",
                      "\\n",
                      "Examples:\\n",
                      "$0 /var/lib/jenkins s3://mybucket/jenkins/jenkins-201405011901.tar.gz\"",
                      "",
                      "JENKINS_HOME=$1",
                      "S3_TARGET=$2",
                      "if [[ -z \"`echo $S3_TARGET|grep '^s3://'`\" || ! -d \"$JENKINS_HOME\" ]]; then",
                      "    echo -e $USAGE",
                      "    exit 1",
                      "fi",
                      "",
                      "LOCAL_BACKUP=/tmp/`basename $S3_TARGET`",
                      "",
                      "tar -C $JENKINS_HOME -zcf $LOCAL_BACKUP .\\",
                      "    --exclude \"config-history/\" \\",
                      "    --exclude \"config-history/*\" \\",
                      "    --exclude \"jobs/*/workspace*\" \\",
                      "    --exclude \"jobs/*/builds/*/archive\" \\",
                      "    --exclude \"plugins/*/*\" \\",
                      "    --exclude \"plugins/*.bak\" \\",
                      "    --exclude \"war\" \\",
                      "    --exclude \"cache\"",
                      "",
                      "aws s3 cp $LOCAL_BACKUP $S3_TARGET",
                      "rm -f $LOCAL_BACKUP"
                    ]
                  ]
                },
                "mode": "000755",
                "owner": "root",
                "group": "root"
              },
              "/etc/cron.daily/jenkins": {
                "content": {
                  "Fn::Join": [
                    "\n",
                    [
                      "#!/bin/bash\n",
                      "AWS_CONFIG_FILE=/etc/aws.conf\n",
                      "PATH=/bin:/usr/bin::/usr/local/bin\n",
                      "source /usr/local/bin/jenkins-backup /var/lib/jenkins s3://{{s3_bucket}}/{{s3_prefix}}jenkins-`date +\\%Y\\%m\\%d\\%H\\%M.tar.gz` >> ~/jenkins.cron.log 2>&1\n",
                      "sleep 60 && /opt/aws/bin/ec2-terminate-instances $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
                    ]
                  ]
                },
                "context": {
                  "s3_bucket": {
                    "Ref": "S3Bucket"
                  },
                  "s3_prefix": {
                    "Ref": "S3Prefix"
                  }
                },
                "mode": "000755",
                "owner": "root",
                "group": "root"
              }
            }
          }
        }
      },
      "Properties": {
        "KeyName": {
          "Ref": "SshKey"
        },
        "IamInstanceProfile": {
          "Ref": "BuildInstanceProfile"
        },
        "ImageId": {
          "Fn::FindInMap": [
            "RegionMap",
            {
              "Ref": "AWS::Region"
            },
            "AMI"
          ]
        },
        "SecurityGroups": [
          {
            "Ref": "ServerSecurityGroup"
          },
          {
            "Ref": "AdminSecurityGroup"
          }
        ],
        "InstanceType": {
          "Ref": "InstanceType"
        },
        "UserData": {
          "Fn::Base64": {
            "Fn::Join": [
              "",
              [
                "#!/bin/bash -xe\n",
                "# Helper function\n",
                "function error_exit\n",
                "{\n",
                "  cfn-signal -e 1 -r \"$1\" '",
                {
                  "Ref": "WaitHandle"
                },
                "'\n",
                "  exit 1\n",
                "}\n",
                "/opt/aws/bin/cfn-init --stack ",
                {
                  "Ref": "AWS::StackName"
                },
                "    --resource LaunchConfig",
                "    --configsets install",
                "    --access-key ",
                {
                  "Ref": "HostKeys"
                },
                "    --secret-key ",
                {
                  "Fn::GetAtt": [
                    "HostKeys",
                    "SecretAccessKey"
                  ]
                },
                "    --region ",
                {
                  "Ref": "AWS::Region"
                },
                " || error_exit 'Failed to run cfn-init'\n",
                "# Post-cfn work\n",
                
                "# Updating to Java 8\n",
                "yum install -y java-1.8.0-openjdk.x86_64 || true \n",
                "sudo /usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java || true\n",
                "sudo /usr/sbin/alternatives --set javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac || true \n",
                "yum remove java-1.7 || true \n",

                "sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo\n",
                "sudo rpm --import http://pkg.jenkins.io/redhat-stable/jenkins.io.key\n",
                "yum install -y jenkins\n",
                "sudo mkdir -p /var/lib/jenkins\n",
                "sudo chown -R jenkins:jenkins /var/lib/jenkins\n",
                "# Handle case where cron doesn't detect the new /etc/cron.d file\n",
                "#service cron restart\n",
                "# Attempt to restore from backup\n",
                "export AWS_CONFIG_FILE=/etc/aws.conf\n",
                "sudo /usr/local/bin/jenkins-restore s3://",
                {
                  "Ref": "S3Bucket"
                },
                "/",
                {
                  "Ref": "S3Prefix"
                },
                " /var/lib/jenkins || true # ignore errors\n",
                "sudo service jenkins start\n",
                "sudo chown -R jenkins:jenkins /var/lib/jenkins\n",
                "sudo chmod -R 755 /var/lib/jenkins\n",
                "# Start Jenkins\n",
                "sudo service jenkins restart\n",
                "sudo chkconfig jenkins on\n",
                "sleep 400\n",
                "printf \"Subject: Your Jenkins Password\n\n",
                "$(cat /var/lib/jenkins/secrets/initialAdminPassword)\n",
                "CHANGE THIS RIGHT AWAY AT: ", 
                "http://",
                {
                  "Ref": "DnsRecord"
                },
                "\" | sendmail -v ", 
                {
                  "Ref": "EmailAddress"
                },
                "\n",
                "# All is well, signal success\n",
                "./opt/aws/bin/cfn-signal --exit-code 0 --reason \"Stack setup complete\" '",
                {
                  "Ref": "WaitHandle"
                },
                "'\n",
                "#EOF"
              ]
            ]
          }
        }
      }
    },
    "LbSecurityGroup": {
      "Type": "AWS::EC2::SecurityGroup",
      "Properties": {
        "GroupDescription": "Jenkins LBs",
        "VpcId": {
          "Ref": "VpcId"
        },
        "SecurityGroupIngress": [
          {
            "IpProtocol": "tcp",
            "FromPort": "80",
            "ToPort": "80",
            "CidrIp": "0.0.0.0/0"
          }
        ]
      }
    },
    "ServerSecurityGroup": {
      "Type": "AWS::EC2::SecurityGroup",
      "Properties": {
        "GroupDescription": "Jenkins servers",
        "VpcId": {
          "Ref": "VpcId"
        },
        "SecurityGroupIngress": [
          {
            "IpProtocol": "tcp",
            "FromPort": "8080",
            "ToPort": "8080",
            "CidrIp": "0.0.0.0/0"
          },
          {
            "IpProtocol": "tcp",
            "FromPort": "22",
            "ToPort": "22",
            "CidrIp": {"Ref" : "IPWhitelist"}
          }
        ]
      }
    },
    "ElasticLoadBalancer": {
      "Type": "AWS::ElasticLoadBalancing::LoadBalancer",
      "Properties": {
        "SecurityGroups": [
          {
            "Ref": "LbSecurityGroup"
          },
          {
            "Ref": "AdminSecurityGroup"
          }
        ],
        "Subnets": {
          "Ref": "Subnets"
        },
        "Listeners": [
          {
            "LoadBalancerPort": "80",
            "InstancePort": "8080",
            "Protocol": "HTTP"
          }
        ],
        "HealthCheck": {
          "Target": "TCP:8080",
          "HealthyThreshold": "3",
          "UnhealthyThreshold": "5",
          "Interval": "30",
          "Timeout": "5"
        }
      }
    },
    "DnsRecord": {
      "Type": "AWS::Route53::RecordSet",
      "Properties": {
        "HostedZoneName": {
          "Fn::Join": [
            "",
            [
              {
                "Ref": "DnsZone"
              },
              "."
            ]
          ]
        },
        "Name": {
          "Fn::Join": [
            "",
            [
              {
                "Ref": "DnsPrefix"
              },
              ".",
              {
                "Ref": "DnsZone"
              },
              "."
            ]
          ]
        },
        "Type": "CNAME",
        "TTL": "900",
        "ResourceRecords": [
          {
            "Fn::GetAtt": [
              "ElasticLoadBalancer",
              "DNSName"
            ]
          }
        ]
      }
    },
    "WaitHandle": {
      "Type": "AWS::CloudFormation::WaitConditionHandle"
    }
  },
  "Outputs": {
    "DnsAddress": {
      "Description": "Jenkins URL",
      "Value": {
        "Fn::Join": [
          "",
          [
            "http://",
            {
              "Ref": "DnsRecord"
            }
          ]
        ]
      }
    }
  }
}
