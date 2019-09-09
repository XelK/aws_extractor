#!/bin/python
"""
    Program that find all running EC2 instances in all aws regions
    use environment variables for aws connection
"""

import boto3
from flask import Flask

#if (('aws_access_key_id' not in os.environ) or ('aws_secret_access_key' not in os.environ)):
#    print("No env variables setted")
#else:
#    print("aws_access_key_id:" + os.environ["aws_access_key_id"])
#    print("aws_secret_access_key:" + os.environ["aws_secret_access_key"])

ec2 = boto3.client('ec2')
response = ec2.describe_instances()
regions = ec2.describe_regions()
results = {}

def extractEc2Info(region, instanceId):
    ''' function that extract EC2 instance info'''
    ec2 = boto3.client('ec2', region_name=region)
    # instanceType
    instanceType=ec2.describe_instance_attribute(InstanceId=instanceId,Attribute="instanceType")['InstanceType']['Value']
    results[region][instanceId].update({'instanceType':instanceType})
    # rootDeviceName
    rootDeviceName=ec2.describe_instance_attribute(InstanceId=instanceId,Attribute='rootDeviceName')['RootDeviceName']['Value']
    results[region][instanceId].update({'rootDeviceName':rootDeviceName})
    # secGroups
    results[region][instanceId].update({'secGroups':[]})
    for groups in ec2.describe_instance_attribute(InstanceId=instanceId,Attribute='groupSet')['Groups']:
        results[region][instanceId]['secGroups'].append(groups['GroupId'])

def findEc2(region):
    ''' function that find EC2 into region'''
    ec2 = boto3.client('ec2',region_name=region)
    resp=ec2.describe_instances()
    for inst in resp['Reservations'][0]['Instances']:
        results[region].update({inst['InstanceId']:{}}) 
        extractEc2Info(region,inst['InstanceId'])

def findRegions():
    ''' function that find regions with running EC2'''
    for region in regions['Regions']:
        ec2 = boto3.client('ec2', region['RegionName'])
        response = ec2.describe_instance_status()
        if response['InstanceStatuses']:
            results.update({region['RegionName']:{}})

def webApp(results):
    ''' function that print web-page'''
    @app.route('/')
    def web_all_region():
        return render_template('template.html', regions=results.keys())
    
    @app.route('/region/<region>')
    def show_region(region):
        return render_template('template.html', selected_region=results[region].keys(),current_region=region)
    
    @app.route('/ec2/<instance>')
    def show_instance(instance):
        for region in results.keys(): 
            for search_instance in results[region].keys(): 
                if search_instance == instance:
                    return render_template('template.html', selected_instance=results[region][instance],current_instance=instance)


''' main program '''
findRegions()
for region in results.keys():
    findEc2(region)
from flask import Flask, escape, render_template
app = Flask(__name__)
webApp(results)

