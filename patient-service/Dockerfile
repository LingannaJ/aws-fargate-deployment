# Use the official Node.js image with a smaller base image (e.g., "node:16-slim")
FROM node:alpine3.20

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy only the package.json and package-lock.json for installing dependencies
COPY package*.json ./

# Install production dependencies only
RUN npm install --production

# Copy the rest of the application files to the working directory
# Avoid copying unnecessary files like node_modules, logs, etc.
COPY . .

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["node", "app.js"]




