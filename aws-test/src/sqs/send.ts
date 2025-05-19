import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import * as dotenv from "dotenv";

dotenv.config();

const REGION = process.env.REGION;
const QUEUE_URL = process.env.QUEUE_URL;

const client = new SQSClient({ region: REGION });

async function sendMessage(): Promise<void> {
  const command = new SendMessageCommand({
    QueueUrl: QUEUE_URL,
    MessageBody: "Hello from TypeScript!",
  });

  try {
    const response = await client.send(command);
    console.log("Message sent successfully:", response.MessageId);
  } catch (error) {
    console.error("Error sending message:", error);
  }
}

sendMessage();
