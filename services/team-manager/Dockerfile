FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -o /team-manager .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /team-manager ./team-manager
EXPOSE 8080
ENTRYPOINT ["./team-manager"]
