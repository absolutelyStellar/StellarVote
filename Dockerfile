FROM golang:1.26-alpine AS builder

RUN apk add --no-cache gcc musl-dev

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/main cmd/api/main.go

FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

RUN addgroup -S app && adduser -S app -G app
USER app

WORKDIR /app
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
