import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

/// Rewrites PNGs without an alpha channel. `adb screencap` emits 32-bit RGBA,
/// which the Play Console rejects for screenshots and feature graphics; it
/// only accepts JPEG or 24-bit PNG there.
///
/// Run it with: java tool/FlattenPng.java <file.png> [more.png ...]
public class FlattenPng {
    public static void main(String[] args) throws Exception {
        for (String path : args) {
            File file = new File(path);
            BufferedImage source = ImageIO.read(file);
            BufferedImage flat = new BufferedImage(
                    source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_RGB);

            Graphics2D g = flat.createGraphics();
            g.setColor(Color.BLACK);
            g.fillRect(0, 0, flat.getWidth(), flat.getHeight());
            g.drawImage(source, 0, 0, null);
            g.dispose();

            ImageIO.write(flat, "png", file);
            System.out.printf(
                    "%s -> %dx%d, %d-bit, alpha=%b%n",
                    path,
                    flat.getWidth(),
                    flat.getHeight(),
                    flat.getColorModel().getPixelSize(),
                    flat.getColorModel().hasAlpha());
        }
    }
}
