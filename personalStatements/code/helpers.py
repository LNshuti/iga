import gzip 
import io 
import pickle
 
 import airflow.utils.dates
 from airflow import DAG 
 from airflow.operators.python import PythonOperator 


from airflow.providers.amazon.aws.operators.s3_copy_object import S3CopyObjectOperator

# Operator copying an objkect on S3 to a different location on S3


s3_copy_object_operator =  S3CopyObjectOperator(
    task_id='copy_file',
    source_bucket_key='my_source_bucket_key',
    dest_bucket_key='my_dest_bucket_key',
    source_bucket_name='my_source_bucket_name',
    dest_bucket_name='my_dest_bucket_name',

)


