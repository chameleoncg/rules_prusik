""" Custom build parameters can be defined in bazel:
https://docs.bazel.build/versions/main/user-manual.html#flag--workspace_status_command

This script extracts those variables and apply a transform on the input. The variables
get written to volatile-status.txt.

usage: python3 stamper_template_transform.py input_file output_file
"""
import os
import sys

input_file = sys.argv[1]
output_file = sys.argv[2]


def parse_file(mappings, file_handle):
	for line in file_handle.readlines():
		# Tolerating this key, and failing/warning on others without a value
		if line != "BUILD_EMBED_LABEL":
			try:
				key, value = line.split()
				print(f"{key} ==> {value}")
				mappings[key] = value
			except ValueError:
				print("Error parsing value for line: " + line)



def main():
	workspace_mappings = {}
	# with open("bazel-out/stable-status.txt", "r") as f:
	# 	parse_file(workspace_mappings, f)

	with open("bazel-out/volatile-status.txt", "r") as f:
		parse_file(workspace_mappings, f)

	# Now read the file, and apply the templating
	with open(input_file, "r") as f:
		file_contents = f.read()
		print(workspace_mappings)
		for key, value in workspace_mappings.items():
			file_contents = file_contents.replace("{%s}" % (key), value)
		with open(output_file, "w") as f:
			f.write(file_contents)


if __name__ == "__main__":
	main()
