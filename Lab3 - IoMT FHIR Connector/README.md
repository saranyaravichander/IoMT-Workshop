# IoMT FHIR Connector for Azure

# Azure API for FHIR

1. Deploy the Azure API for FHIR using the script (Create-AzureApiForFhir.ps1) within the scripts folder
2. Command to run is ./Create-AzureApiForFhir.ps1 -ResourceName <unique-name-for-Azure-API-for-FHIR- resource> -ResourceGroup <resource-group-name>
3. Once the command is run successfully, the output will contain details of the deployed API
            Sample output
                Key   : fhirServerUrl
                Value : https://<unique-name-for-Azure-API-for-FHIR- resource>.azurehealthcareapis.com
                Name  : fhirServerUrl


                Key   : scope
                Value : https://<unique-name-for-Azure-API-for-FHIR- resource>.azurehealthcareapis.com/.default
                Name  : scope


                Key   : accessTokenUrl
                Value : https://login.microsoftonline.com/<>tenantid/oauth2/v2.0/token
                Name  : accessTokenUrl


                Key   : clientId
                Value : <client id of the AD registered app>
                Name  : clientId


                Key   : clientSecret
                Value : <client secret of the AD registered app>
                Name  : clientSecret

4. The output will also be saved in the file named 'fhirapidetails.txt' within the scripts, once the script is run successfully.

# Set up IoT connector feature within Azure API FHIR 

The steps are the same as in the [Azure API for FHIR documentation](https://docs.microsoft.com/en-us/azure/healthcare-apis/iot-fhir-portal-quickstart)

1. Open the Azure portal and go to the Azure API for FHIR resource for which you'd like to create the IoT Connector feature.
2. On the left-hand navigation menu, click on IoT Connector (preview) under the Add-ins section to open the IoT Connectors page.
3. Click on the Add button to open the Create IoT Connector page.
4. Enter settings for the new IoT Connector. Click on Create button and await IoT Connector deployment.
5. Once installation is complete, the newly created IoT Connector will show up on the IoT Connectors page.
6. IoT Connector needs two mapping templates to transform device messages into FHIR-based Observation resource(s): device mapping and FHIR mapping. Your IoT Connector isn't fully operational until these mappings are uploaded
7. To upload mapping templates, click on the newly deployed IoT Connector to go to the IoT Connector page.
8. Device mapping template transforms device data into a normalized schema. On the IoT Connector page, click on Configure device mapping button to go to the Device mapping page.
9. On the Device mapping page, add the following script to the JSON editor and click Save.
            {
            "templateType": "CollectionContent",
            "template": [
                {
                    "templateType": "IotJsonPathContent",
                    "template": {
                        "typeName": "temperature",
                        "typeMatchExpression": "$..[?(@Body.temp)]",
                        "patientIdExpression": "$.SystemProperties.connectionDeviceId",
                        "values": [
                            {
                                "required": "true",
                                "valueExpression": "$.Body.temp",
                                "valueName": "temp"
                            }
                        ]
                    }
                }
            ]
        }
10. FHIR mapping template transforms a normalized message to a FHIR-based Observation resource. On the IoT Connector page, click on Configure FHIR mapping button to go to the FHIR mapping page.
11. On the FHIR mapping page, add the following script to the JSON editor and click Save.
                {
            "templateType": "CollectionFhir",
            "template": [
                {
                    "templateType": "CodeValueFhir",
                    "template": {
                        "codes": [
                            {
                                "code": "8867-4",
                                "system": "http://loinc.org",
                                "display": "Temperature"
                            }
                        ],
                        "periodInterval": 0,
                        "typeName": "temp",
                        "value": {
                            "unit": "degree",
                            "valueName": "temp",
                            "valueType": "Quantity"
                        }
                    }
                }
            ]
        }
12. IoMT device needs a connection string to connect and send messages to IoT Connector. On the IoT Connector page for the newly deployed IoT Connector, select Manage client connections button.
13. Once on Connections page, click on Add button to create a new connection.
14. Provide a friendly name for this connection on the overlay window and select the Create button.
15. Select the newly created connection from the Connections page and copy the value of Primary connection string field from the overlay window on the right.

# Ingest data from IoT Central to Azure API for FHIR using the new IoT connector

1. Open the Iot Central application you created in Lab2
2. Navigate to App Settings -> Data Export
3. Click 'Add' , select Azure Event Hub 
4. Provide a friendly name to the Display name
5. Select 'Use connection string' under 'Event Hub namespace' dropdown
6. Paste the connection details obtained in Step 15 of the previous section
7. Click save

## **Now any new device data coming in through the IoT Central application will flow to Azure API for FHIR**