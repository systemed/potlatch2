package net.systemeD.potlatch2.controller {

    import flash.events.Event;

    /** Defines map-related events. */
    public class ControllerEvent extends Event {

		public static const ENTER_STATE:String = "enter";
		public static const EXIT_STATE:String = "exit";
		public static const SELECTION:String = "select";

		public var state:ControllerState;

        public function ControllerEvent(eventname:String, state:ControllerState) {
            super(eventname);
            this.state=state;
        }
    }

}
