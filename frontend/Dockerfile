# Use official node image as the base image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /frontend

# Copy package.json and package-lock.json to leverage Docker cache
COPY package.json ./
# If you are using npm v7+, also include package-lock.json or yarn.lock
# Optional, if lock file is present
COPY package-lock.json ./  

# Install dependencies
RUN npm install --silent

# Copy the application files
COPY public/ ./public
COPY src/ ./src

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["npm", "start"]