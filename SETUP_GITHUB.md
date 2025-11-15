# Como subir para o GitHub

## Passo 1: Criar o repositório no GitHub

1. Acesse https://github.com/new
2. Preencha:
   - **Repository name:** `experimental-players`
   - **Description:** "Advanced PlayerBot AI for Garry's Mod - Multiplayer Edition"
   - **Visibility:** Public (ou Private, como preferir)
   - ⚠️ **NÃO marque** "Initialize this repository with a README" (já temos um!)
   - ⚠️ **NÃO adicione** .gitignore ou license (já temos!)
3. Clique em **"Create repository"**

## Passo 2: Conectar o repositório local ao GitHub

Depois de criar o repositório, o GitHub vai mostrar instruções. Use estas:

```bash
# No terminal, dentro da pasta experimental-players
git remote add origin https://github.com/Fenri-Lunaedge/experimental-players.git
git push -u origin main
```

Ou se preferir SSH:

```bash
git remote add origin git@github.com:Fenri-Lunaedge/experimental-players.git
git push -u origin main
```

## Passo 3: Verificar

Depois do push, acesse:
https://github.com/Fenri-Lunaedge/experimental-players

Você deve ver:
- README.md exibido
- 11 arquivos
- Licença MIT
- Commit inicial

## Comandos úteis

```bash
# Ver status do repositório
git status

# Ver histórico de commits
git log --oneline

# Ver remote configurado
git remote -v

# Fazer novos commits
git add .
git commit -m "Sua mensagem"
git push
```

---

**Pronto!** Seu mod agora está no GitHub! 🚀
