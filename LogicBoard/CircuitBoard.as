SColor color_powered(225,240,240,60);

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed( false );
    this.getSprite().getConsts().accurateLighting = true;

    this.addCommandID("open");
    this.addCommandID("close");

    this.Tag("place norotate");
	this.Tag("blocks sword");

	this.getCurrentScript().runFlags |= Script::tick_not_attached;

	LogicBoard pcb;	
	this.set("pcbInfo", @pcb);

	const string filepath = "LogicIcons.png";
	Vec2f framesize(32,32);
	
	AddIconToken("$OR$", 	 	 filepath, framesize, 0);
	AddIconToken("$NOR$", 	 	 filepath, framesize, 1);
	AddIconToken("$AND$", 	 	 filepath, framesize, 2);
	AddIconToken("$NAND$", 	 	 filepath, framesize, 3);
	AddIconToken("$XOR$",    	 filepath, framesize, 4);
	AddIconToken("$XNOR$",   	 filepath, framesize, 5);
	AddIconToken("$BUFFER$", 	 filepath, framesize, 6);
	AddIconToken("$NOT$", 	 	 filepath, framesize, 7);
	AddIconToken("$SELECTOR$", 	 filepath, framesize, 8);
	AddIconToken("$TIMER$", 	 filepath, framesize, 9);
	AddIconToken("$COUNTER$", 	 filepath, framesize, 10);
	AddIconToken("$RANDOMIZER$", filepath, framesize, 11);
	AddIconToken("$EMITTER$", 	 filepath, framesize, 12);
	AddIconToken("$WAVEGEN$", 	 filepath, framesize, 13);
	AddIconToken("$BATTERY$", 	 filepath, framesize, 19);

	AddIconToken("$IN_OUT_HOR$",  	filepath, Vec2f(16,16), 64);
	AddIconToken("$IN_VERT$",  		filepath, Vec2f(16,16), 66);
	AddIconToken("$RUBBISH_BIN$",  	filepath, framesize, 18);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{	
	if( !this.isAttached() ) 
	{
		CBitStream params;
		params.write_u16(caller.getNetworkID());
		CButton@ button = caller.CreateGenericButton( "$circuitboard$", Vec2f(0,0), this, this.getCommandID("open"), "Open", params);

		button.enableRadius = 24;
	}
}

void onTick(CBlob@ this)
{	
	LogicBoard@ pcb;
	if (!this.get("pcbInfo", @pcb)) return;	

	CBlob@ user = getBlobByNetworkID(pcb.userID);
	if (user is null) return;

	//if ((user.isKeyJustPressed(key_left) || user.isKeyJustPressed(key_right) || user.isKeyJustPressed(key_up) ||
	//     user.isKeyJustPressed(key_down) || user.isKeyJustPressed(key_action2) || user.isKeyJustPressed(key_action3)) )
	//{
	//	this.SendCommand(this.getCommandID("close"));	
	//}

	pcb.update();
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	LogicBoard@ pcb;
	if (!this.get("pcbInfo", @pcb))
	{
		return;
	}

	if (cmd == this.getCommandID("open"))
	{		
		pcb.open = true;
		pcb.userID = params.read_u16();

		CBlob@ user = getBlobByNetworkID(pcb.userID);
		if (user !is null)
		ClearCarriedBlock(user);
	}
	if (cmd == this.getCommandID("close"))
	{		
		pcb.open = false;
		//pcb.user = null;
	}
}

void ClearCarriedBlock(CBlob@ user)
{
	user.set_u8("buildblob", 255);
	user.set_TileType("buildtile", 0);
	CBlob@ carried = user.getCarriedBlob();
	if(carried !is null && carried.hasTag("temp blob"))
	{
		carried.Untag("temp blob");
		carried.server_Die();
	}
}

void onRender(CSprite@ this)
{
	LogicBoard@ pcb;
	if (!this.getBlob().get("pcbInfo", @pcb)) return;

	CBlob@ user = getBlobByNetworkID(pcb.userID);
	if (user !is null && user.isMyPlayer())
	{		
		pcb.render();
	}	
}

class LogicBoard
{ 
	Vec2f Pos = getDriver().getScreenCenterPos();
	Vec2f BoardDim (256, 256);
	Vec2f buttonDim (16,16);
	Vec2f buttonBorder (6,6);
	bool open;
	u16 userID;

	LogicGate@[] gates;
	BuildMenu@ buildmenu;
	TrashBin@ bin;

	LogicBoard()
	{
		add_BuildMenu();
		add_TrashBin();
	}

	void add_BuildMenu()
	{		
		Vec2f tlPos = (Pos-BoardDim)+Vec2f(16,-56);
		Vec2f brPos = (Pos+Vec2f(BoardDim.x-16, -BoardDim.y-6));
		BuildMenu menu(tlPos, brPos);
		@buildmenu = menu;
	}
	void add_TrashBin()
	{
		TrashBin b(Pos,BoardDim);
		@bin = b;
	}

	void update()
	{
		bin.update();		

		for (uint i = 0; i < gates.length; ++i)
		{		
			LogicGate@ gate = gates[i];
			gate.onBoard = (gate.buttonPos.x > (Pos-BoardDim).x && gate.buttonPos.x < (Pos+BoardDim).x && gate.buttonPos.y > (Pos-BoardDim).y && gate.buttonPos.y < (Pos+BoardDim).y) || (bin.Hovered);

			if (gate.Selected)
			{
				gate.Overlapped = getNeighbours(gate.buttonPos, gates, gate);
			}
			else
			{
				gate.Overlapped = false;
			}

			if (gate.Selected && getControls().isKeyJustReleased(KEY_LBUTTON))
			{	
				if ((!gate.onBoard || gate.Overlapped) && gate.Installed)
				{
					gate.buttonPos = gate.LastPos;
				}
				else if (bin.Hovered || ((!gate.onBoard || gate.Overlapped) && !gate.Installed) )
				{					
					for (uint j = 0; j < gate.inslots.length; ++j)
					{
						gate.inslots[j].deleted = true;
						gate.inslots.erase(j);
					}
					for (uint j = 0; j < gate.outslots.length; ++j)
					{
						gate.outslots[j].deleted = true;
						gate.outslots.erase(j);
					}
					gates.erase(i);
				}
			}
			else if (!gate.Selected && !gate.onBoard && !gate.Installed)
			{										
				for (uint j = 0; j < gate.inslots.length; ++j)
				{
					gate.inslots[j].deleted = true;
					gate.inslots.erase(j);
				}
				for (uint j = 0; j < gate.outslots.length; ++j)
				{
					gate.outslots[j].deleted = true;
					gate.outslots.erase(j);
				}
				gates.erase(i);
			}
			
			if (gate !is null) //since we may have just deleted it
			gate.update();
		}	

		buildmenu.update();		

		for (uint i = 0; i < buildmenu.buttons.length; ++i)
		{
			if (buildmenu.buttons[i].Selected)
			{				
				add_Gate(i);
			}
		}
	}

	void render()
	{
		if (!open || getBlobByNetworkID(userID) is null) return;		

		GUI::DrawFramedPane(Pos-BoardDim-buttonBorder, Pos+BoardDim+buttonBorder);
		GUI::DrawIcon("PCB.png", Pos-BoardDim);

		buildmenu.render();
		bin.render();

		for (int i = 0; i < gates.length; ++i)
		{
			gates[i].render();
		}
	}

	void add_Gate(int type)
	{	
		Vec2f mousePos = getControls().getMouseScreenPos();
		switch (type)
		{
			case 0:  {ORGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 1:  {NORGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 2:  {ANDGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 3:  {NANDGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 4:  {XORGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 5:  {XNORGate gate(); 	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 6:  {BUFFERGate gate(); 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 7:  {NOTGate gate();  	 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 8:  {RandomizerGate gate(); gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 9:  {SelectorGate gate(); 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 10: {WaveGenGate gate(); 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 11: {TimerGate gate(); 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
			case 12: {CounterGate gate(); 	 gate.buttonPos = mousePos; gates.push_back(gate); break;}
		}		
	}
};

bool getNeighbours(Vec2f Pos, LogicGate@[] gates, LogicGate@ selectedgate)
{
	LogicGate@ Neighbour_gate = null;

	for (uint i=0; i < gates.length; i++) 
	{		
		if (gates[i] !is null && gates[i] !is selectedgate)
		{
			if ((Pos + Vec2f(16,0)) == gates[i].buttonPos || (Pos + Vec2f(-16,0)) == gates[i].buttonPos || (Pos + Vec2f(16,16)) == gates[i].buttonPos  ||
				(Pos + Vec2f(0,16)) == gates[i].buttonPos || (Pos + Vec2f( 0,-16)) == gates[i].buttonPos || (Pos + Vec2f(-16,-16)) == gates[i].buttonPos  ||
				(Pos + Vec2f(-16,16)) == gates[i].buttonPos || (Pos + Vec2f(16,-16)) == gates[i].buttonPos  || Pos == gates[i].buttonPos )
			return true;
		}
	}
	return false;
}

class LogicGate
{ 
	Vec2f buttonPos;
	Vec2f buttonDim(16,16);

	string name;
	string icon;
	string description;
	bool Hovered;
	bool Selected;
	bool Powered;
	bool Installed;
	Vec2f LastPos;
	bool onBoard;
	bool Overlapped;

	InputSlot@[] inslots;
	OutputSlot@[] outslots;
	u8 normalinputcount;

	LogicGate(){Installed = false; onBoard = false; Overlapped = false; LastPos = Vec2f_zero; setup();}
 	void setup() {}	

 	void add_InputSlots(u8 count)
	{		
		normalinputcount = count;
		for (uint i = 0; i < count; ++i)
		{
			InputSlot slot();
			slot.Powered = false;
			slot.FunctionSlot = false;
			inslots.push_back(slot); // combine this
			inputs.push_back(slot); // and this			
		}
	}	
	void add_OutputSlots(u8 count)
	{		
		for (uint i = 0; i < count; ++i)
		{
			OutputSlot slot();
			slot.Powered = false;
			outslots.push_back(slot);
		}
	}
	void add_FunctionSlots(u8 count)
	{		
		for (uint i = 0; i < count; ++i)
		{
			InputSlot slot();
			slot.Powered = false;
			slot.FunctionSlot = true;
			inslots.push_back(slot); // combine this
			inputs.push_back(slot); // and this
		}
	}
	
	void update()
	{
		bool justpressedA1 = getControls().isKeyJustPressed(KEY_LBUTTON);
		bool pressedA1 = getControls().isKeyPressed(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();	
		Hovered = (mousePos.x > buttonPos.x- buttonDim.x && mousePos.x < buttonPos.x+buttonDim.x && mousePos.y > buttonPos.y- buttonDim.y && mousePos.y < buttonPos.y+buttonDim.y);

		if (justpressedA1 && Hovered && !Selected)
		{
			Selected = true;
		}
		else if (!pressedA1 && Selected)
		{
			Selected =  false;
			Installed = true;
			LastPos = buttonPos;
		}
		if (Selected)
		{
			buttonPos = Vec2f(Maths::Roundf(mousePos.x/16)*16, 8+Maths::Roundf(mousePos.y/16)*16);
		}
		
		if (outslots.length == 1)
		{		
			Vec2f off( 15, 0);
			outslots[0].Pos = buttonPos+off;
			outslots[0].Powered = Powered;	
			outslots[0].update();
		}
		else
		{
			for (uint i = 0; i < outslots.length; ++i)
			{
				if (inslots[i] !is null)
				{				
					Vec2f off( 15, (i*16)+(i>=0?-8:0));
					outslots[i].Pos = buttonPos+off;
					outslots[i].update();
				}
			}
		}

		for (uint i = 0; i < inslots.length; ++i)
		{
			if (inslots[i] !is null)
			{
				if (!inslots[i].FunctionSlot)
				{
					inslots[i].Pos =( buttonPos-buttonDim) +Vec2f(0, ((normalinputcount)>1?8:16)+(i*16));	
				}
				else
				{
					Vec2f off( ((i-normalinputcount)*16)+(i>(normalinputcount+1)?-8:0), 16);
					inslots[i].Pos = buttonPos+off;					
				}
				inslots[i].update();
			}		
		}

		if ( inslots.length > 0)
		powerupdate();
	}
	void powerupdate() {}

	void render()
	{			
		if (Selected)
			GUI::DrawButtonPressed(buttonPos - buttonDim , buttonPos + buttonDim);
		else if (Hovered)
			GUI::DrawButtonHover(buttonPos - buttonDim , buttonPos + buttonDim);		
		else
			GUI::DrawButton(buttonPos - buttonDim , buttonPos + buttonDim);
		
		if (Powered)
		{				
			GUI::DrawPane(buttonPos - buttonDim , buttonPos + buttonDim, color_powered);
		}	

		for (uint i = 0; i < outslots.length; ++i)
		{			
			outslots[i].render();
		}
		for (uint i = 0; i < inslots.length; ++i)
		{			
			inslots[i].render();			
		}

		GUI::DrawIconByName(icon, buttonPos - buttonDim+Vec2f(0,1), 0.5f);

		extrarender();

		if (!onBoard || Overlapped)
		{
			GUI::DrawRectangle(buttonPos-buttonDim , buttonPos+buttonDim, SColor(150,255,20,20));
		}
	}
	void extrarender() {}
};

class InputSlot
{
	Vec2f Pos;
	Vec2f Dim(8,8);
	bool Selected;
	bool Powered;
	bool Hovered;
	bool FunctionSlot;
	bool deleted;
	Wire@ wire;

	InputSlot() {deleted = false;}

	void update()
	{
		bool pressedA1 = getControls().isKeyPressed(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();
		Hovered = (mousePos.x > Pos.x-Dim.x && mousePos.x < Pos.x+Dim.x && mousePos.y > Pos.y-Dim.y && mousePos.y < Pos.y+Dim.y);
		
		if (wire !is null)
		{				
			Powered = wire.Powered;
			if (wire.outslot.deleted)
			{
				@wire = null;
			}
		}
		else
		{
			Powered = false;
		}	
	}
	void render()
	{
		//if (Hovered || Powered)
		{
			if (!FunctionSlot)			
			GUI::DrawIconByName("$IN_OUT_HOR$", Pos+(Dim*2), -1.0f);
			else
			GUI::DrawIconByName("$IN_VERT$", Pos-(Dim*2),  1.0f);
		}
	}
}

class OutputSlot
{ 
	Vec2f Pos;
	Vec2f Dim(8,8);
	bool Selected;
	bool Powered;
	bool Hovered;
	bool deleted;
	
	Wire@[] wires;

	OutputSlot()  {deleted = false;}

	void update()
	{
		bool justpressedA1 = getControls().isKeyJustPressed(KEY_LBUTTON);
		bool pressingA1 = getControls().isKeyPressed(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();
		Hovered = (mousePos.x > Pos.x-Dim.x && mousePos.x < Pos.x+Dim.x && mousePos.y > Pos.y-Dim.y && mousePos.y < Pos.y+Dim.y);

		if (justpressedA1 && Hovered && !Selected)
		{
			Selected = true;
			add_Wire();
		}
		else if (!pressingA1 && Selected)
		{
			Selected =  false;
		}
		
		for (uint i = 0; i < wires.length; ++i)
		{
			if (wires[i] !is null)
			{
				wires[i].update(Pos);
				if (!Selected && wires[i].inslot is null)
				{
					remove_Wire();
				}
				else if (!Selected && wires[i].inslot.deleted)
				{
					wires.erase(i);
				}
			}
		}		
	}

	void add_Wire()
	{		
		Wire w(Pos, this);
		wires.push_back(w);
	}

	void remove_Wire()
	{	
		wires.removeLast();
	}

	void render()
	{		
		//if (Hovered || Selected || Powered)
		{
			GUI::DrawIconByName("$IN_OUT_HOR$", Pos-Dim-Vec2f(7,7), 1.0f);
		}
		for (uint i = 0; i < wires.length; ++i)
		{
			wires[i].render();
		}
	}
};

class Wire
{ 
	OutputSlot@ outslot;
	InputSlot@ inslot;
	CBlob@ blob;
	bool installed;
	bool Powered;

	Wire() {}

	Wire(Vec2f _Pos, OutputSlot@ _outslot)
	{
		@outslot = _outslot;
		installed = false;
	}

	void update(Vec2f Pos)
	{
		bool pressedA1 = getControls().isKeyPressed(KEY_LBUTTON);
		bool releasedA1 = getControls().isKeyJustReleased(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();
		Vec2f mouseWorldPos = getControls().getMouseWorldPos();

		Powered = (outslot.Powered);

		if (!installed && releasedA1)
		{
			InputSlot@ slot = null;
			@slot = getHoveredInSlot(mousePos);
			if (slot !is null)
			{		
				slot.Powered = Powered;	
				@slot.wire = this;
				@inslot = slot;				
				installed = true;
			}
			else if (ElectricalBlobAtPos(mouseWorldPos) !is null)
			{
				@blob = ElectricalBlobAtPos(mouseWorldPos);
				installed = true;
			}
		}
		else if (blob !is null)
		{		
			blob.SetLight(true);
			blob.getSprite().SetFrameIndex(1);
			blob.Tag("Active");
		}
	}

	void render()
	{
		if (installed && inslot !is null)
		{
			f32 angle = Maths::Abs((outslot.Pos-inslot.Pos).Angle()-180.0f);
			f32 Distance = (outslot.Pos-inslot.Pos).Length();

			if (angle != 0)
			{
				Vec2f h1 = outslot.Pos+Vec2f(32, (inslot.Pos.x < outslot.Pos.x ? (inslot.Pos.y < outslot.Pos.y ? -48 : 48) : 0));

				Vec2f h1GridPos (Maths::Roundf(h1.x/16)*16, -8+Maths::Roundf(h1.y/16)*16);

				Vec2f h2 = inslot.Pos-Vec2f(inslot.FunctionSlot?0:48,inslot.FunctionSlot?-48:(inslot.Pos.x < outslot.Pos.x ? (inslot.Pos.y < outslot.Pos.y ? -48 : 48) : 0));

				Vec2f h2GridPos (Maths::Roundf(h2.x/16)*16, 8+Maths::Roundf(h2.y/16)*16);

				GUI::DrawSpline2D( outslot.Pos, inslot.Pos, h1GridPos, h2GridPos, 8, Powered?color_powered:color_black);
			}
			else
			{
				GUI::DrawLine2D( outslot.Pos+Vec2f(2,0), inslot.Pos+Vec2f(-2,0), Powered?color_powered:color_black);
			}
		}
		else
		{
			Vec2f mousePos = getControls().getMouseScreenPos();
			GUI::DrawLine2D( outslot.Pos, mousePos, Powered?color_powered:color_black);
		}
	}
};

CBlob@ ElectricalBlobAtPos(Vec2f p)
{
	CMap@ map = getMap();
	Vec2f tilespace = map.getTileSpacePosition(p);
	CBlob@ b = map.getBlobAtPosition(p);
	if (b !is null)
	{
		if (b.hasTag("Electrical"))
		{
			return b;
		}
	}
	return null;
}

InputSlot@[] inputs;

InputSlot@ getHoveredInSlot(Vec2f mousePos)
{
	InputSlot@ Hovered_input = null;
	for (uint i=0; i < inputs.length; i++) 
	{		
		if (inputs[i] !is null && inputs[i].Hovered)
		{
			@Hovered_input = inputs[i];
		}
	}
	return Hovered_input;
}

class ORGate : LogicGate
{ 
	void setup() override
	{
		icon = "$OR$";
		name = "OR Gate";
		description = "Outputs power if either input is powered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = (inslots[0].Powered || inslots[1].Powered);		
	}
};

class ANDGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$AND$";
		name = "AND Gate";
		description = "Outputs power if both inputs are powered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{		
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = (inslots[0].Powered && inslots[1].Powered);		
	}
};

class NORGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$NOR$";
		name = "NOR Gate";
		description = "Outputs power if neither inputs are powered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = (!inslots[0].Powered || !inslots[1].Powered);		
	}
};	

class NANDGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$NAND$";
		name = "NAND Gate";
		description = "Outputs power unless both inputs are powered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = (!inslots[0].Powered && !inslots[1].Powered);
	}
};

class XORGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$XOR$";
		name = "XOR Gate";
		description = "Outputs power only if exactly one input is powered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = (inslots[0].Powered && !inslots[1].Powered) || (!inslots[0].Powered && inslots[1].Powered);
	}
};

class XNORGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$XNOR$";
		name = "XNOR Gate";
		description = "Outputs power if both inputs are the same, powered or unpowered";
		Powered = false;
		add_InputSlots(2);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{			
		if (inslots[0] !is null && inslots[1] !is null)
		Powered = ((!inslots[0].Powered && !inslots[1].Powered) || (inslots[0].Powered && inslots[1].Powered));
	}
};

class BUFFERGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$BUFFER$";
		name = "BUFFER Gate";
		description = "Outputs power if input is powered";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
	}
	void powerupdate() override
	{
		if (inslots[0] !is null)
		Powered = inslots[0].Powered;
	}
};

class NOTGate : LogicGate
{ 	
	void setup() override
	{
		icon = "$NOT$";
		name = "NOT Gate";
		description = "Inverts the input signal";
		Powered = true;
		add_InputSlots(1);
		add_OutputSlots(1);
	}

	void powerupdate()
	{			
		if (inslots[0] !is null)
		Powered = !inslots[0].Powered;
	}
}

class RandomizerGate : LogicGate
{ 
	void setup() override
	{
		icon = "$RANDOMIZER$";
		name = "Randomizer";
		description = "Sends power to a random one of it's outputs upon receiving an input signal";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
	}	
	void powerupdate() override
	{
		if (inslots[0] !is null)
		Powered = inslots[0].Powered;
	}
};

class SelectorGate : LogicGate
{ 
	void setup() override
	{
		icon = "$SELECTOR$";
		name = "Selector";
		description = "Cycles between certain outputs";
		Powered = false;
		add_InputSlots(4);
		add_OutputSlots(4);
	}	
	void powerupdate() override
	{
		if (inslots[0] !is null && inslots[1] !is null  && inslots[2] !is null && inslots[3] !is null)
		{			
			outslots[0].Powered = inslots[0].Powered;
			outslots[1].Powered = inslots[1].Powered;
			outslots[2].Powered = inslots[2].Powered;
			outslots[3].Powered = inslots[3].Powered;
		}
	}
};

class WaveGenGate : LogicGate
{ 
	void setup() override
	{
		icon = "$WAVEGEN$";
		name = "Wave Generator";
		description = "Creates a wave signal, outputs the wave value";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
	}		
	void powerupdate() override
	{
		if (inslots[0] !is null )
		Powered = inslots[0].Powered;
	}
};

class TimerGate : LogicGate
{ 
	f32 Charge;
	void setup() override
	{
		icon = "$TIMER$";
		name = "Timer";
		description = "Outputs power when the timer reaches the limit";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
		add_FunctionSlots(1);
		Charge = 0.0f;
	}		
	void powerupdate() override
	{
		if (inslots[0] is null || inslots[1] is null)
		return;

		bool hasPower = inslots[0].Powered;
		f32 TimeLimit = 2.0*60;	

		if (hasPower && Charge < TimeLimit)
		{
			Charge += float(getTicksASecond())*0.1;
		}

		Powered = (hasPower && Charge == TimeLimit);

		if (inslots[1].Powered)	//reset slot
		{
			Charge = 0.0f;
		}			
	}
	void extrarender() override
	{
		f32 TimeLimit = 2.0;
		if (inslots[0].Powered)
		{				
			GUI::DrawRectangle(buttonPos - buttonDim+Vec2f(6,9) , buttonPos + buttonDim +Vec2f(-26+(((1+Charge)/(getTicksASecond()*0.1))/2),-9), color_powered);
		}
	}
};

class BatteryGate : LogicGate
{ 
	f32 Charge;
	void setup() override
	{
		icon = "$BATTERY$";
		name = "Battery";
		description = "Stores power and outputs power if the battery is not empty, drains until empty while not powered";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
		add_FunctionSlots(1);
		Charge = 0.0f;
	}		
	void powerupdate() override
	{
		if (inslots[0] is null || inslots[1] is null)
		return;

		bool hasPower = inslots[0].Powered;
		f32 TimeLimit = 2.0*60;	

		if (hasPower && Charge < TimeLimit)
		{
			Charge += float(getTicksASecond())*0.1;
		}

		Powered = (hasPower && Charge == TimeLimit);

		if (inslots[1].Powered)	//reset slot
		{
			inslots[0].Powered = false;
			Charge = 0.0f;
		}			
	}
	void extrarender() override
	{
		f32 TimeLimit = 2.0;
		if (inslots[0].Powered)
		{				
			GUI::DrawRectangle(buttonPos - buttonDim+Vec2f(6,9) , buttonPos + buttonDim +Vec2f(-26+(((1+Charge)/(getTicksASecond()*0.1))/2),-9), color_powered);
		}
	}
};

class CounterGate : LogicGate
{ 
	u16 Count;
	bool LastFramePowered;

	void setup() override
	{
		icon = "$COUNTER$";
		name = "Counter";
		description = "Counts everytime the input receives power, Activates once the limit count is reached";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
		add_FunctionSlots(1);
		Count = 0;
		LastFramePowered = false;
	}		
	void powerupdate() override
	{
		if (inslots[0] is null || inslots[1] is null)
		return;

		if (!inslots[0].Powered)
		{
			LastFramePowered = false;
		}		

		if (Count == 10)
		{
			Powered = true;
		}	
		else if (inslots[0].Powered && !LastFramePowered)
		{
			Count++;
			LastFramePowered = true;
		}	

		if (inslots[1].Powered)	//reset slot
		{			
			Powered = false;
			inslots[0].Powered = false;
			Count = 0;
		}	
	}	
	void extrarender() override
	{			
		GUI::DrawRectangle(buttonPos - buttonDim+Vec2f(6.5,9) , buttonPos - buttonDim+Vec2f(6.5+(Count*2),24), color_powered);	
		GUI::DrawTextCentered(""+Count, buttonPos-Vec2f(2,2), color_black);	
	}
};

class EmitterGate : LogicGate
{ 
	void setup() override
	{
		icon = "$EMITTER$";
		name = "Emitter";
		description = "Emits objects";
		Powered = false;
		add_InputSlots(1);
		add_OutputSlots(1);
	}		
	void powerupdate() override
	{
		if (inslots[0] is null)
		return;

		Powered = inslots[0].Powered;
	}
};

class RightClickMenu
{ 
	
}

class TrashBin
{ 
	Vec2f buttonDim(24,24);
	Vec2f buttonPos;
	bool Hovered;

	TrashBin(Vec2f menuPos, Vec2f BoardDim) 
	{
		buttonPos = menuPos + Vec2f(BoardDim.x+6, -BoardDim.y-6)+buttonDim;
	}	

	void update()
	{
		bool pressedA1 = getControls().isKeyJustPressed(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();	
		Hovered = (mousePos.x > buttonPos.x- buttonDim.x && mousePos.x < buttonPos.x+buttonDim.x && mousePos.y > buttonPos.y- buttonDim.y && mousePos.y < buttonPos.y+buttonDim.y);
	}

	void render()
	{
		if (Hovered)
		{
			Vec2f outline(4,4);
			GUI::DrawRectangle( buttonPos-buttonDim-outline, buttonPos+buttonDim+outline, color_powered);
		}
		GUI::DrawFramedPane(buttonPos-buttonDim, buttonPos+buttonDim);
		GUI::DrawIconByName("$RUBBISH_BIN$", buttonPos-buttonDim/1.5, 0.5f);		
	}
};

class BuildMenu
{ 
	Vec2f tlPos;
	Vec2f brPos;
	Vec2f buttonDim(16,16);
	string[] Icons;
	Vec2f buttonPos;	
	BuildButton@[] buttons;

	BuildMenu(Vec2f _tlPos, Vec2f _brPos ) {tlPos = _tlPos; brPos = _brPos;  Setup(); }

	void Setup()
	{
		{ BuildButton b( "OR Gate", 		"$OR$", "Outputs power if either input is powered");
			//AddRequirement(b.reqs, "blob", "mat_stone", "Stone", BuilderCosts::stone_block);
			AddButton(b); }
		{ BuildButton b( "NOR Gate",		"$NOR$", "Outputs power if neither inputs are powered");
			AddButton(b); }
		{ BuildButton b( "AND Gate", 		"$AND$", "Outputs power if both inputs are powered");
			AddButton(b); }
		{ BuildButton b( "NAND Gate", 		"$NAND$", "Outputs power unless boths inputs are powered");
			AddButton(b); }
		{ BuildButton b( "XOR Gate", 		"$XOR$", "Outputs power only if one input is powered");
			AddButton(b); }		
		{ BuildButton b( "XNOR Gate", 		"$XNOR$", "Outputs power if both inputs are the same, powered or unpowered");
			AddButton(b); }
		{ BuildButton b( "BUFFER Gate", 	"$BUFFER$", "Outputs power if either input is powered");
			AddButton(b); }	
		{ BuildButton b( "NOT Gate", 		"$NOT$", "Inverts power input");
			AddButton(b); }	
		{ BuildButton b( "Randomizer", 		"$RANDOMIZER$", "Sends power to a random one of it's outputs upon receiving an input signal");
			AddButton(b); }	
		{ BuildButton b( "Selector", 		"$SELECTOR$", "Cycles between certain outputs");
			AddButton(b); }
		{ BuildButton b( "Wave Generator",  "$WAVEGEN$", "Creates a wave signal outputting the wave value");
			AddButton(b); }	
		{ BuildButton b( "Timer", 			"$TIMER$", "Outputs power when the timer is at the limit");
			AddButton(b); }	
		{ BuildButton b( "Counter", 		"$COUNTER$", "Counts everytime the input receives power");
			AddButton(b); }
	}	

	void AddButton(BuildButton@ button)
	{
		buttons.push_back(@button);
		button.buttonPos.x = ((tlPos.x-4)+buttons.length*35);	
		button.buttonPos.y = tlPos.y+25;
	}

	void update()
	{
		for (uint i = 0; i < buttons.length; ++i)
		{
			buttons[i].update();
		}
	}

	void render()
	{
		GUI::DrawFramedPane(tlPos, brPos);

		for (int i = 0; i < buttons.length; ++i)
		{
			buttons[i].render();
		}
	}
};

class BuildButton
{
	string name;
	CBitStream reqs;
	string icon;
	string description;
	Vec2f buttonPos;
	Vec2f buttonDim(16,16);
	bool Hovered;
	bool Selected;

	BuildButton() {}
	BuildButton( string _name, string _icon, string _desc)
	{
		name = _name;
		icon = _icon;
		description = _desc;
	}

	void update()
	{
		bool pressedA1 = getControls().isKeyJustPressed(KEY_LBUTTON);
		Vec2f mousePos = getControls().getMouseScreenPos();	
		Hovered = (mousePos.x > buttonPos.x- buttonDim.x && mousePos.x < buttonPos.x+buttonDim.x && mousePos.y > buttonPos.y- buttonDim.y && mousePos.y < buttonPos.y+buttonDim.y);

		if (pressedA1 && Hovered && !Selected)
		{
			Selected = true;
		}
		else if (!pressedA1 && Selected)
		{
			Selected =  false;
		}
	}

	void render()
	{
		if (Selected)
		{
			GUI::DrawButtonPressed(buttonPos - buttonDim , buttonPos + buttonDim);
		}
		else if (Hovered)
		{
			GUI::DrawButtonHover(buttonPos - buttonDim , buttonPos + buttonDim);			
			GUI::DrawText(name+"\n\n"+description+"\n", buttonPos + buttonDim*2.5 +Vec2f(-128, 0), buttonPos + buttonDim+Vec2f(128,128), color_black, false, false, true);
		}		
		else
		{
			GUI::DrawButton(buttonPos - buttonDim , buttonPos + buttonDim);
		}		
		
		GUI::DrawIconByName(icon, buttonPos- buttonDim+Vec2f(0,1), 0.5f);
	}
};