from django.db import connection
from django.http import HttpResponse


def home(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT version();")
        postgres_version = cursor.fetchone()[0]

    return HttpResponse(
        "<h1>Django + PostgreSQL on EKS</h1>"
        f"<p>PostgreSQL connection works: {postgres_version}</p>"
        "<p>Deployed via Kubernetes on Amazon EKS 🚀</p>"
    )
