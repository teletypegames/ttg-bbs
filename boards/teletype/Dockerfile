# Build stage
FROM golang:1.26.1-alpine AS builder

WORKDIR /app

# Install dependencies
COPY go.mod ./
# COPY go.sum ./ # Uncomment if you have a go.sum file
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bbs-server main.go

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/bbs-server .

# Expose the port
EXPOSE 2323

# Run the binary
CMD ["./bbs-server"]
