import java.util.*;
import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class LayerFrame extends JFrame {
  private Vector<Listener> listeners;
  private final JPanel panel;
  private final Vector<Layer> layers;

  public LayerFrame() {
    super("Layers");

    listeners = new Vector<Listener>();
    layers = new Vector<Layer>();

    this.panel = new JPanel();
    panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
    add(panel);

    setVisible(true);
  }

  public void addLayer(String name) {
    Layer layer = new Layer(this, name);
    layers.add(layer);

    panel.add(layer.checkBox);
    pack();

    for (Listener listener : listeners) {
      listener.layerAdded(name);
    }
  }

  public boolean isEnabled(String name) {
    for (Layer layer : layers) {
      if (layer.name.equals(name)) {
        return layer.checkBox.isSelected();
      }
    }

    throw new RuntimeException("Unrecognized layer name: \"" + name + "\"");
  }

  public void addListener(Listener listener) {
    listeners.add(listener);
  }

  interface Listener {
    public void layerAdded(String name);
    public void layerEnabled(String name);
    public void layerDisabled(String name);
  }

  private class Layer implements ItemListener {
    private LayerFrame parent;
    public final String name;
    public final JCheckBox checkBox;

    public Layer(LayerFrame parent, String name) {
      this.parent = parent;
      this.name = name;
      this.checkBox = new JCheckBox(name, true);

      this.checkBox.addItemListener(this);
    }

    public void itemStateChanged(ItemEvent itemEvent) {
      if (itemEvent.getStateChange() == ItemEvent.SELECTED) {
        for (Listener listener : this.parent.listeners) {
          listener.layerEnabled(name);
        }
      } else if (itemEvent.getStateChange() == ItemEvent.DESELECTED) {
        for (Listener listener : this.parent.listeners) {
          listener.layerDisabled(name);
        }
      }
    }
  }
}