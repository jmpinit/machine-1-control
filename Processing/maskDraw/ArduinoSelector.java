import java.util.*;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JRadioButton;
import javax.swing.JButton;
import javax.swing.ButtonGroup;
import javax.swing.ButtonModel;
import javax.swing.BoxLayout;
import java.awt.event.*;

public class ArduinoSelector extends JFrame implements ActionListener {
  private static final String[] DISALLOWED_PORT_SIGNATURES = {
    "Bluetooth",
    "SPPD",
    "iPhone"
  };

  private final ButtonGroup arduinoGroup;
  private final SelectionListener selectionListener;

  public ArduinoSelector(String[] portPaths, SelectionListener selectionListener) {
    super("Select an Arduino");

    this.selectionListener = selectionListener;

    JPanel panel = new JPanel();
    panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));

    arduinoGroup = new ButtonGroup();

    JRadioButton[] radios = new JRadioButton[portPaths.length];
    for (int i = 0; i < portPaths.length; i++) {
      radios[i] = new JRadioButton(portPaths[i]);
      radios[i].setActionCommand(portPaths[i]);
      arduinoGroup.add(radios[i]);
      panel.add(radios[i]);
    }

    JButton button = new JButton("Select");
    button.addActionListener(this);
    panel.add(button);

    add(panel);
    setDefaultLookAndFeelDecorated(true);
    pack();
    setVisible(true);
  }

  public void actionPerformed(ActionEvent e) {
    if (e.getActionCommand() == "Select") {
      ButtonModel model = this.arduinoGroup.getSelection();

      if (model == null) {
        // No selection was made
        return;
      }

      this.selectionListener.selected(model.getActionCommand());
      dispose();
    }
  }

  public static List filterPorts(String[] serialPortPaths) {
    Vector<String> possiblePorts = new Vector<String>();

    for (String portPath : serialPortPaths) {
      boolean allowed = true;

      for (String disallowedSignature : DISALLOWED_PORT_SIGNATURES) {
        if (portPath.contains(disallowedSignature)) {
          allowed = false;
          break;
        }
      }

      if (allowed) {
        possiblePorts.add(portPath);
      }
    }

    return possiblePorts;
  }

  interface SelectionListener {
    public void selected(String port);
  }
}
