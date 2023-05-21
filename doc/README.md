# Documentation
<!-- markdownlint-disable MD013 -->
This folder contains markdown documentation files for *SecBench*. It can be used
either directly or as a basis for generating self contained documentation like
PDF, DOCX etc. The PDF documentation is generated using *pandoc*.

## Build Documentation (local)

The documentation is based on markdown. This allows to convert it to
different formats e.g. PDF, DOCX, PPTX and DokuWiki

- Create *PDF* using a local *pandoc* installation. This requires also latex.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/*.md
pandoc --metadata-file=doc/metadata.yml \
--listings --pdf-engine=xelatex \
--resource-path=images \
--filter pandoc-latex-environment \
--output=doc/secbench_guide.pdf doc/?x??-*.md
```

- Create *DOCX* using a local *pandoc* installation.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/*.md
pandoc --metadata-file=doc/metadata.yml \
--listings \
--resource-path=images \
--output=doc/secbench_guide.docx doc/?x??-*.md
```

- Create *Markdown* file using a local pandoc installation.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/*.md
pandoc --metadata-file=doc/metadata.yml \
--listings \
--resource-path=images \
--output=doc/secbench_guide.md doc/?x??-*.md
```

## Build Documentation (container)

The documentation is based on markdown. This allows to convert it to
different formats e.g. PDF, DOCX, PPTX and DokuWiki

- Create *PDF* using a container.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/*.md
docker run -v "$PWD":/workdir:z oehrlis/pandoc --metadata-file=doc/metadata.yml \
--listings --pdf-engine=xelatex \
--resource-path=images \
--filter pandoc-latex-environment \
--output=doc/secbench_guide.pdf doc/?x??-*.md
```

- Create *DOCX* using a local pandoc installation.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/A008/*.md
docker run -v "$PWD":/workdir:z oehrlis/pandoc --metadata-file=doc/metadata.yml \
--listings \
--resource-path=images \
--output=doc/secbench_guide.docx doc/?x??-*.md
```

- Create *Markdown* file using a local pandoc installation.

```bash
sed -i 's/\(^!\[.*\](\).*images\/\(.*\)/\1\2/' doc/*.md
docker run -v "$PWD":/workdir:z oehrlis/pandoc --metadata-file=doc/metadata.yml \
--listings \
--resource-path=images \
--output=doc/secbench_guide.md doc/?x??-*.md
```
