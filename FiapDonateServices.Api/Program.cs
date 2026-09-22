using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();
builder.Services.AddSingleton<InfrastructureMetrics>();

var app = builder.Build();

app.Use(async (context, next) =>
{
    var metrics = context.RequestServices.GetRequiredService<InfrastructureMetrics>();
    metrics.RecordRequest(context.Request.Method, context.Request.Path.Value ?? "/", context.Response.StatusCode);
    await next();
});

app.MapHealthChecks("/health");
app.MapHealthChecks("/ready");

app.MapGet("/api/status", (IConfiguration configuration) => new
{
    service = "FiapDonateServices",
    status = "ok",
    environment = app.Environment.EnvironmentName,
    configuration = new
    {
        campaignApiBaseUrl = configuration["CampaignApi__BaseUrl"] ?? "http://fiapdonate-campaign",
        usersApiBaseUrl = configuration["UsersApi__BaseUrl"] ?? "http://fiapdonate-users",
        receiverApiBaseUrl = configuration["ReceiverApi__BaseUrl"] ?? "http://fiapdonate-receiver",
        workerApiBaseUrl = configuration["WorkerApi__BaseUrl"] ?? "http://fiapdonate-worker",
        rabbitMqHost = configuration["RabbitMQ__Host"] ?? "rabbitmq",
        rabbitMqPort = configuration["RabbitMQ__Port"] ?? "5672",
        rabbitMqVirtualHost = configuration["RabbitMQ__VirtualHost"] ?? "/"
    }
});

app.MapPost("/api/observability/donation-processed", (InfrastructureMetrics metrics) =>
{
    metrics.RecordDonationProcessed();
    return Results.Ok(new { message = "Donation processed event received." });
});

app.MapPost("/api/observability/message-rejected", (InfrastructureMetrics metrics) =>
{
    metrics.RecordMessageRejected();
    return Results.Ok(new { message = "Message rejected event received." });
});

app.MapGet("/metrics", (InfrastructureMetrics metrics) =>
{
    var content = metrics.ToPrometheusText();
    return Results.Text(content, "text/plain; version=1.0; charset=utf-8");
});

app.Run();

public sealed class InfrastructureMetrics
{
    private readonly object _sync = new();
    private long _httpRequests;
    private long _donationsProcessed;
    private long _messagesRejected;

    public void RecordRequest(string method, string path, int statusCode)
    {
        lock (_sync)
        {
            _httpRequests++;
        }
    }

    public void RecordDonationProcessed()
    {
        lock (_sync)
        {
            _donationsProcessed++;
        }
    }

    public void RecordMessageRejected()
    {
        lock (_sync)
        {
            _messagesRejected++;
        }
    }

    public string ToPrometheusText()
    {
        lock (_sync)
        {
            var sb = new StringBuilder();
            sb.AppendLine("# HELP fiapdonate_http_requests_total Total de requisições HTTP recebidas pelo serviço de infraestrutura.");
            sb.AppendLine("# TYPE fiapdonate_http_requests_total counter");
            sb.AppendLine($"fiapdonate_http_requests_total {_httpRequests}");

            sb.AppendLine("# HELP fiapdonate_donations_processed_total Total de doações processadas pelo fluxo.");
            sb.AppendLine("# TYPE fiapdonate_donations_processed_total counter");
            sb.AppendLine($"fiapdonate_donations_processed_total {_donationsProcessed}");

            sb.AppendLine("# HELP fiapdonate_messages_rejected_total Total de mensagens rejeitadas pelo processamento assíncrono.");
            sb.AppendLine("# TYPE fiapdonate_messages_rejected_total counter");
            sb.AppendLine($"fiapdonate_messages_rejected_total {_messagesRejected}");

            return sb.ToString();
        }
    }
}
