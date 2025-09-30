# Use Node 16 (matches your pipeline)
FROM node:16-bullseye

# Create app dir
WORKDIR /app

# Install only what package.json declares
COPY package*.json ./
# try npm ci first (fast, lockfile-respecting); fall back to npm install
RUN (npm ci --omit=dev || npm install --omit=dev)

# Copy the rest of the app
COPY . .

# The AWS EB express sample typically listens on 8081 via process.env.PORT
ENV PORT=8081
EXPOSE 8081

# Start the server
CMD ["node", "app.js"]
