# FBX Processing Tool for 3ds Max

A comprehensive MAXScript tool for batch importing, cleaning, and optimizing FBX files in 3ds Max.


## Features

- **Batch FBX Import**: Process entire folders of FBX files with a single operation
- **Smart Sorting Options**: Sort files alphabetically or by size (ascending/descending)
- **Automatic Scene Cleaning**: Removes unnecessary objects like lights, cameras, helpers, etc.
- **Material-Based Merging**: Intelligently combines objects with the same material
- **Memory-Optimized Processing**: Adaptive batch sizing based on scene complexity
- **Progress Tracking**: Real-time feedback on processing status
- **Multi-Stage Pipeline**: Import, clean, and merge in a seamless workflow

## Benefits

### For Corona Renderer
- Creates optimal scene structure for proxy creation
- Streamlines material application
- Reduces scene complexity while maintaining visual fidelity

### For Unreal Engine
- Prevents creation of countless duplicate materials during import
- Simplifies object positioning and manipulation
- Makes LOD implementation more straightforward
- Optimizes geometry for Nanite activation

## Installation

1. Download all script files:
   - `main.ms`
   - `cleaner.ms`
   - `merge.ms`
   - `importer.ms`
   
2. Place all files in the same directory, preferably in your 3ds Max scripts folder.

3. Run the main script from 3ds Max by:
   ```
   fileIn "path/to/main.ms"
   ```
   
   Or create a button on your toolbar by dragging the MAXScript icon to your toolbar and assigning the script to it.

## Usage

### Main Interface

The main interface provides access to all tool functions:

- **Import FBX Files**: Launch the FBX import settings dialog
- **Clean Current Scene**: Remove unnecessary objects from the current scene
- **Merge By Material**: Merge objects by material in the current scene
- **Import, Clean & Merge**: Run the complete workflow

### Batch Import Settings

When selecting the Import function, you can configure:

1. **Import Mode**:
   - Directory (Batch Import)
   - Single File

2. **Sort Order**:
   - Alphabetical
   - Size (Smallest First)
   - Size (Largest First)

3. **Processing Options**:
   - Clean scene after import
   - Merge by material after cleaning
   - Save processed files (.max)

## Best Practices

- For very large datasets, sort by size (largest first) to process the most memory-intensive files when 3ds Max has the most available resources
- Enable "Save processed files" to create .max files automatically for future use
- Consider breaking extremely large imports into multiple folder batches

## Technical Details

The tool consists of three main modules:

1. **Cleaner Module**: Removes non-essential objects and returns geometry
2. **Merger Module**: Combines objects with identical materials using optimized memory management
3. **Importer Module**: Handles FBX file importing with progress tracking and batch processing

## Requirements

- 3ds Max 2018 or newer
- Sufficient RAM for handling your model complexity

## Author

Matheus de Oliveira Leite

---

If you find this tool useful, please consider starring the repository and sharing your experience!