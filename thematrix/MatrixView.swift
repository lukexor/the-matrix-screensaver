import ScreenSaver

var GLYPHS: [NSMutableString] = ["0", "1", "2", "3", "4", "5", "7", "8", "9", "Z", " ", ":", ".", "\"", "-", "+", "*", ";", "|", "_", "╌", "*", "=", "ç", "<", ">", "¦"]

var FONT = NSFont(name: "GN-Koharuiro_Sunray", size: 24)
var SIZE: Int = 15
var SPEED_MIN: CGFloat = 150
var SPEED_MAX: CGFloat = 450

func randomGlyph() -> NSMutableString {
    return GLYPHS[Int(SSRandomIntBetween(0, Int32(GLYPHS.count - 1)))]
}

struct Glyph {
    var value: NSMutableString = randomGlyph()
    let MORPH_PROB: Int = 10
    
    mutating func update() {
        if SSRandomIntBetween(0, 3000) <= MORPH_PROB {
            value = randomGlyph()
        }
    }

    func draw(x: CGFloat, y: CGFloat, color: NSColor) {
        value.draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: FONT ?? NSFont(name: "Courier New", size: 24)!,
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
        y = SSRandomFloatBetween(-1000, -20) // START RANGE
        max_height = height;
        speed = SSRandomFloatBetween(SPEED_MIN, SPEED_MAX)
        if SSRandomIntBetween(0, 100) <= HIGHLIGHT_PROB {
            highlight = true;
        }
        let count = Int(SSRandomIntBetween(1, 30)) // HEIGHT RANGE
        self.height = CGFloat(count * SIZE)
        glyphs.reserveCapacity(count)
        for _ in 0...count {
            glyphs.append(Glyph.init())
        }
    }

    func shouldSpawn() -> Bool {
        let height_threshold = SSRandomFloatBetween(0.3 * max_height, 0.4 * max_height) // SHOULD SPAWN RANGE
        return !spawned && (y - height) > height_threshold
    }

    mutating func spawn() -> Self {
        spawned = true;
        var stream = Stream(x: x, height: max_height)
        stream.speed = speed
        stream.y = SSRandomFloatBetween(-100, -10) // SPAWN RANGE
        return stream
    }
    
    mutating func update(_ delta_time: DateInterval) {
        y += delta_time.duration * speed
        for (i, _) in glyphs.enumerated() {
            glyphs[i].update()
        }
    }

    func draw(_ height: CGFloat) {
        for (i, glyph) in glyphs.enumerated() {
            let y = y - CGFloat(i * SIZE)
            if y < 0.0 - CGFloat(SIZE) || y > height {
                continue
            }
            var color = color
            if i == 0 && highlight {
                color = HIGHLIGHT
            }
            glyph.draw(x: x, y: y, color: color)
        }
    }
}

struct Matrix {
    var streams: [Stream] = []
    var new_streams: [Stream] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
    var last_time: Date = Date()

    init(width: CGFloat, height: CGFloat) {
        for i in 0...95 {
            GLYPHS.append(NSMutableString(string: String(UnicodeScalar(0x30A0 + i)!)))
        }
        self.width = width;
        self.height = height;
        let count = Int(self.width) / SIZE
        streams.reserveCapacity(count + 200)
        new_streams.reserveCapacity(200)
        for i in 0...count-1 {
            streams.append(Stream.init(x: CGFloat(i * SIZE), height: height))
        }
    }

    mutating func update() {
        let now = Date()
        let time_since_last = DateInterval(start: last_time, end: now)
        last_time = now
        for (i, _) in streams.enumerated() {
            streams[i].update(time_since_last)
            if streams[i].shouldSpawn() {
                new_streams.append(streams[i].spawn())
            }
        }
        streams.removeAll { (stream: Stream) -> Bool in
            return stream.y > height + stream.height
        }
        streams.append(contentsOf: new_streams)
        new_streams.removeAll()
    }
    
    func draw() {
        streams.forEach { stream in
            stream.draw(height)
        }
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
    private var matrix: Matrix?
    private var transform: NSAffineTransform?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        if (isPreview) {
            FONT = NSFont(name: "GN-Koharuiro_Sunray", size: 12)
            SIZE = 8
            SPEED_MIN = 50
            SPEED_MAX = 300
        }
        registerCustomFonts()
        animationTimeInterval = 1.0/24.0;
    }

    override var isFlipped: Bool {
        get { return true }
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func startAnimation() {
        super.startAnimation()
        matrix = Matrix.init(width: frame.width, height: frame.height)
        transform = NSAffineTransform(transform: AffineTransform(translationByX: frame.width, byY: 0.0))
        transform?.scaleX(by: -1.0, yBy: 1.0)
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        matrix = nil
        transform = nil
    }
    
    override func draw(_ rect: NSRect) {
        super.draw(rect)
        transform?.concat()
        matrix?.draw()
    }
    
    override var isOpaque: Bool {
        get { return true }
    }

    override func animateOneFrame() {
        super.animateOneFrame()
        matrix?.update()
        setNeedsDisplay(bounds)
    }
    
    override var hasConfigureSheet: Bool {
        get { return false }
    }
    
    override var configureSheet: NSWindow? {
        get { return nil }
    }
}
