FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
COPY migrations ./migrations
RUN CGO_ENABLED=0 go build -o /team-manager .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /team-manager ./team-manager
EXPOSE 8080
ENTRYPOINT ["./team-manager"]
