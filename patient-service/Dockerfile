# Use the official Node.js Alpine image
FROM node:18-alpine

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies (without unnecessary npm cache)
RUN npm install --production && npm cache clean --force

# Copy application source code
COPY . .

# Expose the application port
EXPOSE 3000

# Command to run the application
CMD ["node", "app.js"]


