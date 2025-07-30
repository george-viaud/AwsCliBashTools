import boto3
import concurrent.futures
import threading
import sys
import os

MAX_KEYS = 1000
MAX_WORKERS = 16

total_deleted = 0
lock = threading.Lock()

def delete_objects(s3, bucket, keys):
    global total_deleted
    if not keys:
        return
    try:
        response = s3.delete_objects(
            Bucket=bucket,
            Delete={'Objects': [{'Key': key} for key in keys]}
        )
        deleted_count = len(response.get('Deleted', []))
        with lock:
            total_deleted += deleted_count
            print(f"Deleted: {total_deleted // 1000}K objects", end='\r')
    except Exception as e:
        print(f"\nError deleting batch: {e}")

def main():
    if len(sys.argv) != 2 or sys.argv[1] in ('--help', '-h'):
        script_name = os.path.basename(sys.argv[0])
        print(f"Usage: python {script_name} <bucket-name>")
        sys.exit(1)

    bucket = sys.argv[1]
    s3 = boto3.client('s3')
    keys_batch = []
    futures = []

    print(f"Starting deletion of bucket: {bucket}")

    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=bucket):
            contents = page.get('Contents', [])
            for obj in contents:
                keys_batch.append(obj['Key'])
                if len(keys_batch) == MAX_KEYS:
                    futures.append(executor.submit(delete_objects, s3, bucket, keys_batch))
                    keys_batch = []
            if keys_batch:
                futures.append(executor.submit(delete_objects, s3, bucket, keys_batch))
                keys_batch = []

        concurrent.futures.wait(futures)

    try:
        s3.delete_bucket(Bucket=bucket)
        print(f"\nBucket '{bucket}' deleted successfully.")
    except Exception as e:
        print(f"\nError deleting bucket: {e}")

if __name__ == "__main__":
    main()
