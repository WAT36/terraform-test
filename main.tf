provider "aws" {
  region = "ap-northeast-1"  # 利用したいAWSリージョン
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-terraform-testbucket"  # グローバルに一意な名前を指定
  acl    = "private"  # バケットのアクセス制御（private, public-read など）

  tags = {
    Name        = "MyS3Bucket"
    Environment = "Dev"
  }
}
