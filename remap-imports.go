package main

// TODO: Copy files to generated dir even if not .sol suffix
// TODO: Stop if src-generated exists already
// TOOO: Add .md file and file header to generated dir/files with info
// TODO: Resolve import if sol file is in deeper dir structure

import (
	"bufio"
	"errors"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"
)

const (
	libFolder    = "../lib"
	srcFolder    = "./src"
	newSrcFolder = "./src-generated"
)

func main() {

	// Create new src folder, delete old if exists.
	os.RemoveAll(newSrcFolder)
	err := os.Mkdir(newSrcFolder, 0750)
	if err != nil {
		log.Fatal(err)
	}

	// Get each file for ./src/*.sol
	dir, err := ioutil.ReadDir(srcFolder)
	if err != nil {
		log.Fatal(err)
	}

	for _, fileInfo := range dir {
		// Skip if file is not .sol.
		if !strings.HasSuffix(fileInfo.Name(), ".sol") {
			continue
		}

		// Open file.
		file, err := os.Open(path.Join(srcFolder, fileInfo.Name()))
		if err != nil {
			log.Fatal(err)
		}

		// Create new file in generated src folder.
		generatedFile, err := os.Create(path.Join(newSrcFolder, fileInfo.Name()))
		if err != nil {
			log.Fatal(err)
		}

		writer := bufio.NewWriter(generatedFile)

		// Read file line by line.
		scanner := bufio.NewScanner(file)
		scanner.Split(bufio.ScanLines)
		for scanner.Scan() {
			line := scanner.Text()

			// If line is not import statement, copy to generatedFile and continue.
			if !strings.Contains(line, "import") {
				writer.WriteString(line)
				writer.WriteString("\n")
				writer.Flush()
				continue
			}

			// If local import path, copy and continue.
			if strings.Contains(line, "from \"./") {
				writer.WriteString(line)
				writer.WriteString("\n")
				writer.Flush()
				continue
			}

			// If local import path with import whole file, copy and continue.
			if !strings.Contains(line, "{") {
				writer.WriteString(line)
				writer.WriteString("\n")
				writer.Flush()
				continue
			}

			// Could be:
			// import {...} from "..."	<--
			// import "..."				<-- This case is not needed
			// import {					<-- Read next 2 lines to get import

			// If multine line import statement, read 2 next lines and concat.
			if !strings.Contains(line, "}") {
				// Read next two lines.
				scanner.Scan()
				nextLine := strings.Trim(scanner.Text(), " ")
				scanner.Scan()
				nNextLine := scanner.Text()

				// Concat lines to line, remove newline symbol.
				line += strings.ReplaceAll(nextLine, "\n", "")
				line += strings.ReplaceAll(nNextLine, "\n", "")
			}

			// Substitute import statement.
			tokens := strings.Split(line, " ")
			contractName := strings.ReplaceAll(tokens[1], "{", "")
			contractName = strings.ReplaceAll(contractName, "}", "")

			importString := tokens[3]

			newImportStatement, err := createImportStatement(contractName, importString)
			if err != nil {
				log.Fatal(err)
			}

			writer.WriteString(newImportStatement)
			writer.WriteString("\n")
			writer.Flush()
		}

		// Close files.
		file.Close()
		generatedFile.Close()
	}

}

func createImportStatement(contractName, importString string) (string, error) {
	result := "import {" + contractName + "}" + " from "

	// Find import in lib folder.
	path := strings.Split(importString, "/")
	if len(path) < 2 {
		return "", errors.New("Invalid import string: " + importString)
	}

	newPath := "\"" + libFolder + "/" + strings.ReplaceAll(path[0], "\"", "") + "/src/"
	if len(path) == 2 {
		newPath += path[1]
		return result + newPath, nil
	}

	if len(path) == 3 {
		newPath += path[1] + "/" + path[2]
		return result + newPath, nil
	}

	return "", errors.New("Invalid import string: " + importString)
}
