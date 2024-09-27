import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_1/picture_block/block_data.dart';
import 'dart:async';

import 'package:flutter_application_1/picture_block/block_sequence.dart';
import 'package:provider/provider.dart';

class VirtualTile {
  final int index; // Index of the tile in the grid
  final String tileType; // Type of the tile

  VirtualTile(this.index, this.tileType); // Constructor
}

class Level {
  final int id;
  final int gridN;
  final List<VirtualTile> grid;
  final int dollStartX;
  final int dollStartY;

  Level(this.id, this.gridN, this.grid, this.dollStartX, this.dollStartY);

  static Future<Level> create(int id, int startX, int startY) async {
    String content = await rootBundle.loadString('assets/levels/level_$id.txt');
    List<String> lines = content.trim().split('\n');
    int gridN = lines.length; // get gridN
    List<VirtualTile> grid = [];

    for (int y = 0; y < gridN; y++) {
      List<String> tiles = lines[y].trim().split(' ');
      for (int x = 0; x < gridN; x++) {
        grid.add(VirtualTile(y * gridN + x, tiles[x]));
      }
    }

    return Level(id, gridN, grid, startX, startY);
  }
}

class VirtualController extends ChangeNotifier {
  List<Level> levels = []; // List of levels in the game
  int currentLevelIndex = 0; // Index of the currently active level
  Level? currentLevel; // The current level object
  int babyX = 0; // X-coordinate of the baby's position
  int babyY = 0; // Y-coordinate of the baby's position
  List<VirtualTile> activeGrid = []; // The grid of tiles currently active
  bool isLoading = true; // Loading state indicator
  BlockSequence blockSequence = BlockSequence(); // Block sequence manager

  VirtualController() {
    _initializeLevels(); // Initialize levels on controller creation
  }

  Future<void> _initializeLevels() async {
    try {
      // Create and initialize levels asynchronously
      levels = await Future.wait([
        Level.create(1, 0, 1),
        Level.create(2, 0, 2),
        Level.create(3, 0, 0),
        Level.create(4, 0, 0),
      ]);

      currentLevel = levels[currentLevelIndex]; // Set the current level
      _resetLevel(); // Reset the current level state
      isLoading = false; // Set loading to false after levels are initialized
      notifyListeners(); // Notify listeners about the state change
    } catch (error) {
      // Handle errors during level initialization
      print('Error initializing levels: $error');
      isLoading = false; // Set loading to false on error
      notifyListeners(); // Notify listeners about the state change
    }
  }

  void _resetLevel() {
    if (currentLevel == null) return; // Return if there's no current level

    // Set initial position for the baby based on the level's starting position
    babyX = currentLevel!.dollStartX;
    babyY = currentLevel!.dollStartY;

    // Validate the starting position
    if (babyX < 0 || babyX >= currentLevel!.gridN || babyY < 0 || babyY >= currentLevel!.gridN) {
      print('Invalid start position for level ${currentLevel!.id}: ($babyX, $babyY)');
      babyX = 0; // Reset to default if invalid
      babyY = 0;
    }

    activeGrid = List.from(currentLevel!.grid); // Initialize the active grid
    _drawBaby(); // Draw the baby on the grid
    notifyListeners(); // Notify listeners about the state change

    print('Reset level ${currentLevel!.id}. Baby should go position: ($babyX, $babyY)');
  }

  void _drawBaby() {
    if (currentLevel == null) return; // Return if there's no current level

    // Calculate the index for the baby's current position
    int curIndex = babyY * currentLevel!.gridN + babyX;
    if (curIndex >= 0 && curIndex < currentLevel!.grid.length) {
      // Replace existing tile with the baby tile
      for (int i = 0; i < currentLevel!.grid.length; i++) {
        if (activeGrid[i].tileType == 'the_doll') {
          activeGrid[i] = currentLevel!.grid[i]; // Replace with the original tile
        }
      }
      activeGrid[curIndex] = VirtualTile(curIndex, 'the_doll'); // Draw baby tile at the current position
      notifyListeners(); // Notify listeners about the state change
      print('Baby actual draw position: ($babyX, $babyY)');
    } else {
      print('Invalid baby position: ($babyX, $babyY) for grid size ${currentLevel!.gridN}');
    }
  }

  bool _checkBabyPosition(int x, int y) {
    if (currentLevel == null) return false; // Return false if there's no current level
    // Check if the new position is within the grid bounds
    if (x < 0 || x >= currentLevel!.gridN || y < 0 || y >= currentLevel!.gridN) {
      return false; // Out of grid range
    }
    int index = y * currentLevel!.gridN + x; // Calculate index based on x, y
    if (index < 0 || index >= currentLevel!.grid.length) {
      return false; // Invalid index
    }
    String tileType = currentLevel!.grid[index].tileType; // Get the tile type at the position
    if (tileType == 'pink') {
      return false; // Cannot move to pink tile
    } else if (tileType == 'start_doll') {
      endOfLevel(); // If reached starting point, end the level
      return false;
    }
    return true; // Can move to other types of tiles
  }

  void moveBaby(String direction) {
    if (currentLevel == null) return; // Return if there's no current level
    int newX = babyX; // Initialize new X position
    int newY = babyY; // Initialize new Y position

    // Update the new position based on the direction
    switch (direction) {
      case 'left':
        newX = babyX - 1;
        break;
      case 'right':
        newX = babyX + 1;
        break;
      case 'up':
        newY = babyY - 1;
        break;
      case 'down':
        newY = babyY + 1;
        break;
    }

    // Check if the new position is valid and update the position if so
    if (_checkBabyPosition(newX, newY)) {
      babyX = newX;
      babyY = newY;
      _drawBaby(); // Redraw the baby at the new position
      notifyListeners(); // Notify listeners about the state change
      print('After move - Baby now position: ($babyX, $babyY)');
    } else {
      _shakeBaby(); // Call shake method if movement is invalid
    }
  }

  void _shakeBaby() {
    // Notify listeners is not needed as it doesn't affect UI
    // Just show Snackbar or error message
    String errorMessage = 'Cannot move there!'; // Error message
    notifyListeners(); // Notify listeners about the state change
  }

  void endOfLevel() {
    // Logic for ending the level
    nextLevel(); // Move to the next level
    notifyListeners(); // Notify listeners about the state change
  }

  void nextLevel() {
    if (currentLevelIndex < levels.length - 1) {
      currentLevelIndex++; // Increment level index
      currentLevel = levels[currentLevelIndex]; // Set new current level
      _resetLevel(); // Reset the new level
      notifyListeners(); // Notify listeners about the state change
    }
  }

  void previousLevel() {
    if (currentLevelIndex > 0) {
      currentLevelIndex--; // Decrement level index
      currentLevel = levels[currentLevelIndex]; // Set new current level
      _resetLevel(); // Reset the new level
      notifyListeners(); // Notify listeners about the state change
    }
  }

  void executeMoves(List<BlockData> blocks) async {
    // Execute a sequence of moves based on the provided block data
    for (var block in blocks) {
      switch (block.imagePath) {
        case 'assets/images/move_up.png':
          moveBaby('up'); // Move up
          break;
        case 'assets/images/move_down.png':
          moveBaby('down'); // Move down
          break;
        case 'assets/images/move_left.png':
          moveBaby('left'); // Move left
          break;
        case 'assets/images/move_right.png':
          moveBaby('right'); // Move right
          break;
      }
      await Future.delayed(Duration(milliseconds: 500)); // Delay between moves
    }
  }
}

@override
Widget build(BuildContext context) {
  // Create a ChangeNotifierProvider for the VirtualController
  return ChangeNotifierProvider(
    create: (context) => VirtualController(),
    child: Consumer<VirtualController>( // Listen to changes in VirtualController
      builder: (context, virtualController, child) {
        // Show loading indicator while the levels are being initialized
        if (virtualController.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        // Check if the current level is loaded properly
        if (virtualController.currentLevel == null) {
          return Center(child: Text('Error loading levels'));
        }

        return Column(
          children: [
            // Display the current level ID
            Text('Level ${virtualController.currentLevel!.id}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              // Create a square grid for the active grid
              child: AspectRatio(
                aspectRatio: 1, // Maintain a square shape
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: virtualController.currentLevel!.gridN, // Set number of columns based on grid size
                  ),
                  itemCount: virtualController.activeGrid.length, // Set the number of items in the grid
                  itemBuilder: (context, index) {
                    // Create a grid item for each tile in the active grid
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(), // Add border to each grid item
                      ),
                      child: Image.asset(
                        'assets/blocks/${virtualController.activeGrid[index].tileType}.png',
                        fit: BoxFit.contain, // Ensure the image fits within the cell
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Direction buttons for moving the doll
                  ElevatedButton(
                    onPressed: () => virtualController.moveBaby('left'), // Move left
                    child: Icon(Icons.arrow_left),
                  ),
                  ElevatedButton(
                    onPressed: () => virtualController.moveBaby('up'), // Move up
                    child: Icon(Icons.arrow_upward),
                  ),
                  ElevatedButton(
                    onPressed: () => virtualController.moveBaby('down'), // Move down
                    child: Icon(Icons.arrow_downward),
                  ),
                  ElevatedButton(
                    onPressed: () => virtualController.moveBaby('right'), // Move right
                    child: Icon(Icons.arrow_right),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Button to go to the previous level
                ElevatedButton(
                  onPressed: virtualController.previousLevel,
                  child: Text('Previous Level'),
                ),
                // Button to go to the next level
                ElevatedButton(
                  onPressed: virtualController.nextLevel,
                  child: Text('Next Level'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
