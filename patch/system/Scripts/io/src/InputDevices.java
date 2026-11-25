package java.io;

// OpenSLRR (#345): the controllers SDL3 sees, for Options > Controls.
// Index i is the device ControlSet and Input call i + 3. A device that is
// unplugged keeps its index (connected() returns 0).
public class InputDevices
{
	public final static int	FIRST_DEVICE = 3;

	public static native int	refresh();	// asks SDL again; returns count()
	public static native int	count();
	public static native String	name( int i );
	public static native String	type( int i );		// "WHEEL", "PS5 PAD", "JOYSTICK"...
	public static native String	power( int i );		// "WIRED", "BATTERY", "CHARGING", "CHARGED" or ""
	public static native int	connected( int i );
	public static native int	axes( int i );
	public static native int	buttons( int i );
	public static native int	hats( int i );
	public static native int	battery( int i );	// percent, -1 when unknown
	public static native int	canRumble( int i );
	public static native float	activity( int i );	// 0..1, strongest input right now
	public static native int	rumble( int i, float strength, int milliseconds );

	// Axis range calibration: move every axis to both ends, then end it.
	public static native void	calibrateBegin( int i );
	public static native int	calibrateEnd( int i );	// 0 when no axis moved
	public static native void	calibrateReset( int i );
	public static native int	calibrated( int i );
	public static native int	calibrating( int i );
}
