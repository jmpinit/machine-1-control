import hypermedia.net.UDP;

public class ViveConnection {
  private final float SCALE = 100;

  private UDP socket;
  private float x, y, z;
  private float rx, ry, rz;
  private boolean triggerPressed, padPressed, gripPressed;

  public void connect(String host, int port) {
    socket = new UDP(this, port, host);
    socket.listen(true);
  }

  void receive(byte[] data, String HOST_IP, int PORT_RX) {
    String message = new String(data);
    String parts[] = message.split(";");

    long ticks = Long.parseLong(parts[0]);
    x = (float)Double.parseDouble(parts[1]) * SCALE;
    y = (float)Double.parseDouble(parts[2]) * SCALE;
    z = (float)Double.parseDouble(parts[3]) * SCALE;

    rx = (float)(Double.parseDouble(parts[4]) / 360.0f * 2 * Math.PI);
    ry = (float)(Double.parseDouble(parts[5]) / 360.0f * 2 * Math.PI);
    rz = (float)(Double.parseDouble(parts[6]) / 360.0f * 2 * Math.PI);

    triggerPressed = Integer.parseInt(parts[7]) > 0;
    padPressed = Integer.parseInt(parts[8]) > 0;
    gripPressed = Integer.parseInt(parts[9]) > 0;
    
    System.out.println(x + ", " + y + ", " + z);
  }

  float posX() { return x; }
  float posY() { return y; }
  float posZ() { return z; }

  float rotationX() { return rx; }
  float rotationY() { return ry; }
  float rotationZ() { return rz; }

  boolean triggerPressed() { return triggerPressed; }
  boolean padPressed() { return padPressed; }
  boolean gripPressed() { return gripPressed; }
}