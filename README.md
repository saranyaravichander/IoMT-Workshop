# Pre-requisites

Hardware 

 - A PC running Windows 10 Anniversary Update or later (Version 1607 or greater) 
- An unused USB port on the PC 
- An Avnet Azure Sphere Starter Kit 
- A micro USB cable to connect the Starter Kit to your PC 

Software 

 - Visual Studio 2019 version 16.4 or later (Enterprise, Professional,
   or Community version)  
 - Azure Sphere SDK 20.01 or the current SDK
   release

Others 

- An Azure subscription 
- Power Apps license 

# Architecture

![alt text](./images/diagram1.jpg "Process Flow")


# Workshop Breakdown

## 1. Successful setup of Azure Sphere device
> a. Setup an Azure Sphere Tenant 
> 	b. Access our Azure Sphere Tenant 
	> c. Update the OS on our Azure Sphere device 
	> d. Claim our Azure Sphere device to our tenant 
	> e. Configure the Wi-Fi on our device and verify that it’s connected to a Wi-Fi network 
> 	f. Enable-development mode on device

## 2. Run a program on the Sphere device to extract sensor data
> a. Pull an Azure Sphere project down from GitHub 
	> b. Review the different build options in the project 
	> c. Build and run the project

## 3. Set up IoT Central application

> a. Create an IoT Central application from a template 
> b. Provision our device to the IoT Central application 
> c. Configure the example application for the IoT Central configuration

## 4. Push data to a FHIR Server
> a. Set up IoMT connector to read from IoT Central
> b. Set up Azure API for FHIR
> c. Send data to Azure API for FHIR

## 5. Visualize sensor data

> a. Set up Power App
> b. Visualize temperature sensor data on Power App
