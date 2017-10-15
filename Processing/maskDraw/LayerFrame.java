import java.util.*;
import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class LayerFrame extends JFrame {
  private final JPanel panel;
  private final Vector<Layer> layers;

  public LayerFrame() {
    super("Layers");

    layers = new Vector<Layer>();

    this.panel = new JPanel();
    panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
    add(panel);

    setVisible(true);
  }

  public void addLayer(String name) {
    Layer layer = new Layer(name);
    layers.add(layer);

    panel.add(layer.checkBox);
    pack();
  }

  public boolean isEnabled(String name) {
    for (Layer layer : layers) {
      if (layer.name == name) {
        return layer.checkBox.isSelected();
      }
    }

    throw new RuntimeException("Unrecognized layer name: \"" + name + "\"");
  }

  private class Layer {
    public final String name;
    public final JCheckBox checkBox;

    public Layer(String name) {
      this.name = name;
      this.checkBox = new JCheckBox(name);
      
      // Selected by default
      this.checkBox.setSelected(true);
    }
  }
}