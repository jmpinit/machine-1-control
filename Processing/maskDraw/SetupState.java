import processing.core.*;

public class SetupState {
  private Plotter plotter;
  private PVector currentPos;
  private PVector lowerRight;

  public SetupState(Plotter plotter) {
    this.plotter = plotter;
    this.currentPos = new PVector(0, 0);

    // Start with 1x1m canvas
    this.lowerRight = new PVector(1000, 1000);
  }

  public void jogUp() {
    currentPos.y -= 10;
    plotter.moveTo(currentPos.x, currentPos.y);
  }

  public void jogLeft() {
    currentPos.x -= 10;
    plotter.moveTo(currentPos.x, currentPos.y);
  }

  public void jogDown() {
    currentPos.y += 10;
    plotter.moveTo(currentPos.x, currentPos.y);
  }

  public void jogRight() {
    currentPos.x += 10;
    plotter.moveTo(currentPos.x, currentPos.y);
  }

  public void setLowerRight() {
    this.lowerRight = this.currentPos.copy();
  }

  public PVector currentPosition() {
    return currentPos;
  }

  public Bounds getBounds() {
    return new Bounds(0, 0, lowerRight.x, lowerRight.y);
  }

  public Bounds getScreenBounds(float width, float height) {
    Bounds bounds = getBounds();
    float aspectRatio = bounds.height / bounds.width;
    float boundsWidth = width * 0.8f;
    float boundsHeight = boundsWidth * aspectRatio;
    float offsetX = (width - boundsWidth) / 2.0f;
    float offsetY = (height - boundsHeight) / 2.0f;

    return new Bounds(offsetX, offsetY, boundsWidth, boundsHeight);
  }
}
