import {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
} from "@aws-sdk/client-sqs";
import * as dotenv from "dotenv";

dotenv.config();

const REGION = process.env.REGION;
const QUEUE_URL = process.env.QUEUE_URL;

const client = new SQSClient({ region: REGION });

async function receiveMessages(): Promise<void> {
  const command = new ReceiveMessageCommand({
    QueueUrl: QUEUE_URL,
    MaxNumberOfMessages: 1,
    WaitTimeSeconds: 10,
  });

  try {
    const response = await client.send(command);
    const messages = response.Messages;

    if (!messages || messages.length === 0) {
      console.log("No messages received.");
      return;
    }

    for (const message of messages) {
      console.log("Received message:", message.Body);

      // 削除処理
      if (message.ReceiptHandle) {
        await client.send(
          new DeleteMessageCommand({
            QueueUrl: QUEUE_URL,
            ReceiptHandle: message.ReceiptHandle,
          })
        );
        console.log("Message deleted.");
      }
    }
  } catch (error) {
    console.error("Error receiving messages:", error);
  }
}

receiveMessages();
