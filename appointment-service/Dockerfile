# Dockerfile for Appointment Service

# Use an official Node.js runtime as a base image
FROM node:14-alpine

# Set the working directory
WORKDIR /usr/src/app

# Copy the package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose the application port (default is 3001)
EXPOSE 3001

# Command to run the app
CMD [ "node", "appointment-service.js" ]
