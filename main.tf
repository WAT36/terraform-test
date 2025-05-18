provider "aws" {
  region = "ap-northeast-1"  # 利用したいAWSリージョン
}

resource "aws_sqs_queue" "example_queue" {
  name                      = "my-example-queue"
  delay_seconds             = 0
  max_message_size          = 262144   # デフォルト: 256KB
  message_retention_seconds = 345600   # デフォルト: 4日
  receive_wait_time_seconds = 10
}
