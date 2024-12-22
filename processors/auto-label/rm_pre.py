import json
import os


def remove_prefix_from_image_path(input_file, output_file, prefix_to_remove, batch_size=10000):
    total_lines = 0
    processed_lines = 0
    if not os.path.exists(input_file):
        print(f"Input file '{input_file}' does not exist.")
        return

    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        batch = []
        for line in infile:
            try:
                # Parse each line as a JSON object
                data = json.loads(line)

                # Remove the prefix from image_path if it exists
                if 'image_path' in data and data['image_path'].startswith(prefix_to_remove):
                    data['image_path'] = data['image_path'].replace(prefix_to_remove, '', 1)

                # Add the modified data to the batch
                batch.append(json.dumps(data))
                total_lines += 1

                # Write the batch in chunks
                if len(batch) >= batch_size:
                    outfile.write('\n'.join(batch) + '\n')
                    processed_lines += len(batch)
                    batch = []  # Clear the batch
                    print(f"Processed {processed_lines} lines...")

            except json.JSONDecodeError as e:
                print(f"Skipping invalid JSON line: {e}")

        # Write any remaining items in the batch
        if batch:
            outfile.write('\n'.join(batch) + '\n')
            processed_lines += len(batch)

    print(f"Total processed lines: {processed_lines}")
    print(f"Output written to '{output_file}'")


if __name__ == "__main__":
    input_file = '/Users/macadelic/MainProjects/auto-label/output/embeddings.jsonl'  # Replace with your input JSONL file
    output_file = 'output_embeddings.jsonl'  # Replace with your output JSONL file
    prefix_to_remove = '/Users/macadelic/pikaso/sync_products/dwnlded/'  # The prefix to remove

    # Execute the function
    remove_prefix_from_image_path(input_file, output_file, prefix_to_remove)
