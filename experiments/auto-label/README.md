# SpeedGo

Can download & accurately resize images based on dimensions and then normalize color channels for data pipeline.

```bash
go build -o speedgo main.go
```

```bash
# [app_name] [file_type] [input_dir] [output_dir]

./speedgo yaml /Users/macadelic/thnk_projects/thnk_ml/yaml_out images
./speedgo txt updated_urls_one.txt images
```

```bash
...
Successfully resized images/wine-tumbler-white-front-643ea99f713e6_grande.png
Successfully resized images/unisex-premium-hoodie-military-green-front-6438396c43946_grande.png
Embeddings generated and saved to data/nomic_embeddings.jsonl
```

```bash
ruby get_emb.rb
```

```bash
ruby label_service.rb
```

```bash
ruby script.rb
```
