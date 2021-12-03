import ScreenSaver

var GLYPHS: [String] = ["0", "1", "2", "3", "4", "5", "7", "8", "9", "Z", " ", ":", ".", "\"", "-", "+", "*", ";", "|", "_", "╌", "*", "=", "ç", "<", ">", "¦"]

var FONT = NSFont(name: "GN-Koharuiro_Sunray", size: 24)
let HEIGHT: Int = 15
let HEIGHTF: CGFloat = 15.0
let WIDTH: Int = 15

struct Glyph {
    var value: NSMutableString = ""
    let MORPH_PROB: Int = 10

    init() {
        self.value.setString(self.randomGlyph())
    }

    func randomGlyph() -> String {
        return GLYPHS[Int(SSRandomIntBetween(0, Int32(GLYPHS.count - 1)))]
    }

    mutating func draw(x: CGFloat, y: CGFloat, color: NSColor) {
        if SSRandomIntBetween(0, 1000) <= self.MORPH_PROB {
            self.value.setString(self.randomGlyph())
        }
        self.value.draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: FONT!,
            .foregroundColor: color,
        ])
    }
}

struct Stream {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var height: CGFloat = 0
    var max_height: CGFloat = 0
    var highlight: Bool = false
    var glyphs: [Glyph] = []
    var color = NSColor(red: 0.24, green: 1.0, blue: 0.27, alpha: 1.0)
    var speed: CGFloat = 0
    var spawned: Bool = false

    let HIGHLIGHT_PROB: Int = 30
    let HIGHLIGHT = NSColor(red: 0.75, green: 1.0, blue: 0.78, alpha: 1.0)

    init(x: CGFloat, height: CGFloat) {
        self.x = x
        self.y = SSRandomFloatBetween(-300, -100) // START RANGE
        self.max_height = height;
        self.randomize()
    }

    mutating func randomize() {
        self.speed = SSRandomFloatBetween(5, 15) // SPEED RANGE
        if SSRandomIntBetween(0, 100) <= self.HIGHLIGHT_PROB {
            self.highlight = true;
        }
        let count = Int(SSRandomIntBetween(1, 25)) // HEIGHT RANGE
        self.height = CGFloat(count * HEIGHT)
        for _ in 0...count {
            self.glyphs.append(Glyph.init())
        }
    }

    func shouldSpawn() -> Bool {
        let height_threshold = SSRandomFloatBetween(300, 450) // SHOULD SPAWN RANGE
        return !self.spawned && (self.y - self.height) > height_threshold
    }

    mutating func spawn() -> Self {
        self.spawned = true;
        var stream = Self.init(x: self.x, height: self.max_height)
        stream.speed = self.speed
        stream.y = SSRandomFloatBetween(-100, -10) // SPAWN RANGE
        return stream
    }

    mutating func draw(_ height: CGFloat) {
        self.y += self.speed
        for (i, _) in self.glyphs.enumerated() {
            let y = self.y - CGFloat(i) * HEIGHTF
            if y < 0.0 - HEIGHTF || y > height {
                continue
            }
            var color = self.color
            if i == 0 && self.highlight {
                color = self.HIGHLIGHT
            }
            self.glyphs[i].draw(x: self.x, y: y, color: color)
        }
    }
}

struct Matrix {
    var streams: [Stream] = []
    var new_streams: [Stream] = []
    var width: CGFloat = 0
    var height: CGFloat = 0

    init(width: CGFloat, height: CGFloat) {
        for i in 0...95 {
            GLYPHS.append(String(UnicodeScalar(0x30A0 + i)!))
        }
        self.width = width;
        self.height = height;
        let count = Int(self.width) / WIDTH
        for i in 0...count-1 {
            self.streams.append(Stream.init(x: CGFloat(i * WIDTH), height: height))
        }
    }
    
    mutating func onUpdate(_ rect: NSRect) {
        self.streams.removeAll { (stream: Stream) -> Bool in
            return stream.y > self.height + stream.height
        }
        for (i, _) in self.streams.enumerated() {
            self.streams[i].draw(self.height)
            if self.streams[i].shouldSpawn() {
                self.new_streams.append(self.streams[i].spawn())
            }
        }
        self.streams.append(contentsOf: self.new_streams)
        self.new_streams.removeAll()
    }
}

func registerCustomFonts() {
    let paths = Bundle.main.paths(forResourcesOfType: "ttf", inDirectory: "")
    for path in paths {
        let fontUrl = NSURL(fileURLWithPath: path)
        var errorRef: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontUrl, .persistent, &errorRef)
        if (errorRef != nil) {
            let error = errorRef!.takeRetainedValue()
            print("Error registering custom font: \(error)")
        }
    }
}

class MatrixView: ScreenSaverView {
    private var matrix: Matrix
    private var transform: NSAffineTransform
    
    override init?(frame: NSRect, isPreview: Bool) {
        registerCustomFonts()
        matrix = Matrix.init(width: frame.width, height: frame.height)
        transform = NSAffineTransform(transform: AffineTransform(translationByX: frame.width, byY: 0.0))
        transform.scaleX(by: -1.0, yBy: 1.0)
        
        super.init(frame: frame, isPreview: isPreview)
    }
    
    override var isFlipped: Bool {
        get { return true }
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: NSRect) {
        super.draw(rect)
        transform.concat()
        matrix.onUpdate(bounds)
    }
    
    override func animateOneFrame() {
        super.animateOneFrame()
        setNeedsDisplay(bounds)
    }
}
