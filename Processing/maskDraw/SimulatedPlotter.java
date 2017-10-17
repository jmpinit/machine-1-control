import processing.core.PVector;
import java.util.Vector;

public class SimulatedPlotter extends Plotter {
  private final float VELOCITY = 1000;

  public SimulatedPlotter(Tool tool, float mmPerXStep, float mmPerYStep, float mmPerZStep, float widthInMM, float heightInMM) {
    super(tool, mmPerXStep, mmPerYStep, mmPerZStep, widthInMM, heightInMM);
  }

  protected void processNextInstruction() {
    if (!instructions.isEmpty()) {
      Instruction nextInstruction = instructions.firstElement();
      instructions.remove(0);

      int[] instruction = nextInstruction.getData();

      char command = (char)instruction[0];
      int x = (instruction[2] << 8) | instruction[1];
      int y = (instruction[4] << 8) | instruction[3];
      int z = (instruction[6] << 8) | instruction[5];

      switch (command) {
        case 'm':
          PVector pos = path.lastElement();
          int timeToCompleteMove = (int)(1000 * dist(pos.x, pos.y, pos.z, x, y, z) / VELOCITY);

          try {
            Thread.sleep(timeToCompleteMove);
          } catch (InterruptedException e) {}

          synchronized (path) {
            path.add(new PVector(x, y, z));
          }
          break;
        case 'r':
          // TODO implement
          break;
        case 's':
          spraying = x == 1;
          break;
        default:
          throw new RuntimeException("Unrecognized command");
      }
    } else {
      try {
        Thread.sleep(10);
      } catch (InterruptedException e) {}
    }
  }

  private float dist(float x1, float y1, float z1, float x2, float y2, float z2) {
    return (float)Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2) + Math.pow(z2 - z1, 2));
  }
}