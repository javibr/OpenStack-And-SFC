# OpenStack && Service Function Chaining working as a really close friends

Here are given a serie of bash scripts to deploy the SFC scenarios mentioned in my final thesis, entitled SERVICE FUNCTION CHAINING EN NFV: EVALUACIÓN PRÁCTICA CON OPENSTACK

# How to run 

First of all, you need an Ubuntu 14.04 server (16 can suits too), the resources are very valuable in this project, so be sure of having at least 10 GB RAM and two processors.

# Playing around

To deploy OpenStack, you need to follow my thesis (it is attached as tfg_JavierBautista), after all the problems you will encounter (because you will), try to run the script sfc_scenario.sh, it will deploy the first scenario of the thesis, play around with it until you break everything, but do not worry, we are playing in a virtual environment ;)

Everytime you want to deploy a new scenario, it is neccesary to do an ```unstack.sh```.

# What is Service Function Chaining

SFC is a new architecture which allows the packets to flow along the network depending on the type of traffic. It has a serveral pros like saving a lot of resources, because you don't have to route your VoIP packets through a Parental Control while your children needs to. Imagine this in a Bank, where there are millions of requests and not every packet needs to go through an IDS.

![A picture of SFC](https://www.sdxcentral.com/wp-content/uploads/2016/02/MKT2014097243EN_fig03.jpg)

If you are still interested in what you have seen, I encourage you to take a look to my thesis.
