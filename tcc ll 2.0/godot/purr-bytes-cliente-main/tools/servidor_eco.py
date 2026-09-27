#!/usr/bin/env python3
"""Servidor de eco para desenvolver o transporte HTTP (Marco 3) sem depender
das rotas reais de `Morc3go/prototipo` (ainda nao implementadas -- ver
docs/decisoes/0003-telemetria-fila-e-transporte.md).

Aceita qualquer POST em /v1/sessoes*, responde 202 (o mesmo codigo que a API
real usa: "aceito para processar", nao "gravado") e grava o corpo recebido
como uma linha JSON em ARQUIVO_DE_LOG -- e o que os testes de integracao do
Godot leem para conferir campo a campo contra o contrato.

Uso:
    python servidor_eco.py <porta> <arquivo_de_log>

Sem retentativa, sem estado, sem validacao de schema: o objetivo e so dar ao
cliente HTTP algo real para conversar, e testar resiliencia matando este
processo no meio de uma partida (a mesma tecnica que tests/teste_fase_03_integracao.gd
usa) -- nao simular todo o back-end.
"""

import http.server
import json
import sys
import time


class Handler(http.server.BaseHTTPRequestHandler):
    log_path = None

    def do_POST(self):
        tamanho = int(self.headers.get("Content-Length", 0))
        corpo_bruto = self.rfile.read(tamanho) if tamanho > 0 else b""
        try:
            corpo = json.loads(corpo_bruto) if corpo_bruto else {}
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return

        registro = {
            "recebido_em": time.time(),
            "metodo": "POST",
            "caminho": self.path,
            "autorizacao": self.headers.get("Authorization", ""),
            "corpo": corpo,
        }
        with open(Handler.log_path, "a", encoding="utf-8") as arquivo:
            arquivo.write(json.dumps(registro) + "\n")

        self.send_response(202)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        pass  # silencioso -- quem quer ver o trafego le o arquivo de log


def main():
    porta = int(sys.argv[1])
    Handler.log_path = sys.argv[2]
    servidor = http.server.HTTPServer(("127.0.0.1", porta), Handler)
    print("servidor de eco ouvindo em 127.0.0.1:%d" % porta, flush=True)
    servidor.serve_forever()


if __name__ == "__main__":
    main()
