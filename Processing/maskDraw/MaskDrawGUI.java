import java.util.Vector;
import java.io.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.image.BufferedImage;

import javax.swing.JFileChooser;
import javax.imageio.ImageIO;

import processing.core.PImage;

public class MaskDrawGUI {
  private final Vector<Listener> listeners;

  public MaskDrawGUI(final Frame frame) {
    listeners = new Vector<Listener>();

    MenuBar menu = new MenuBar();

    Menu fileMenu = new Menu("File");
    MenuItem importItem = new MenuItem("Import image");
    importItem.addActionListener(new ActionListener () {
      public void actionPerformed(ActionEvent e) {
        System.out.println("Image import triggered");

        final JFileChooser fileChooser = new JFileChooser();
        int fileRet = fileChooser.showOpenDialog(frame);

        if (fileRet == JFileChooser.APPROVE_OPTION) {
          File imageFile = fileChooser.getSelectedFile();

          BufferedImage image;
          try {
            image = ImageIO.read(imageFile);
          } catch (IOException exception) {
            throw new RuntimeException("Failed to read image");
          }

          imageImported(imageFile.getName(), new PImage(image));
        } else {
          System.out.println("File choosing failed");
        }
      }
    });

    fileMenu.add(importItem);
    menu.add(fileMenu);

    frame.setMenuBar(menu);
  }

  public void addListener(Listener listener) {
    listeners.add(listener);
  }

  public void imageImported(String name, PImage image) {
    for (Listener listener : listeners) {
      listener.imageImported(name, image);
    }
  }

  interface Listener {
    public void imageImported(String name, PImage image);
  }
}