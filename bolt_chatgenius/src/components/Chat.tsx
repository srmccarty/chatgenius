import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { MessageSquare, Users, LogOut, Plus } from 'lucide-react';

// Define TypeScript interfaces for your data
interface Channel {
  id: string;
  name: string;
  description?: string;
  created_at: string;
  created_by: string;
}

interface Message {
  id: string;
  channel_id: string;
  content: string;
  created_at: string;
  user_id: string;
  // Add other relevant fields
}

interface User {
  id: string;
  username: string;
  // Add other relevant fields
}

export function Chat() {
  const [channels, setChannels] = useState<Channel[]>([]);
  const [currentChannel, setCurrentChannel] = useState<Channel | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState<string>('');
  const [users, setUsers] = useState<User[]>([]);
  const [showNewChannel, setShowNewChannel] = useState<boolean>(false);
  const [newChannelName, setNewChannelName] = useState<string>('');
  const [newChannelDesc, setNewChannelDesc] = useState<string>('');

  useEffect(() => {
    fetchChannels();
    fetchUsers();
    
    const messagesSubscription = supabase
      .channel('messages')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'messages' }, 
        (payload: any) => { // Ideally, replace 'any' with a proper type
          if (payload.new && payload.new.channel_id === currentChannel?.id) {
            setMessages(prev => [...prev, payload.new]);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(messagesSubscription);
    };
  }, [currentChannel]);

  const fetchChannels = async (): Promise<void> => {
    const { data, error } = await supabase
      .from<Channel>('channels')
      .select('*')
      .order('created_at');

    if (error) {
      console.error('Error fetching channels:', error);
    } else {
      setChannels(data || []);
    }
  };

  const fetchUsers = async (): Promise<void> => {
    const { data, error } = await supabase
      .from<User>('users')
      .select('*');

    if (error) {
      console.error('Error fetching users:', error);
    } else {
      setUsers(data || []);
    }
  };

  const fetchMessages = async (channelId: string): Promise<void> => {
    const { data, error } = await supabase
      .from<Message>('messages')
      .select('*')
      .eq('channel_id', channelId)
      .order('created_at', { ascending: true });

    if (error) {
      console.error('Error fetching messages:', error);
    } else {
      setMessages(data || []);
    }
  };

  const createChannel = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    if (!newChannelName.trim()) return;

    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      console.error('Error fetching user:', userError);
      return;
    }
    
    const { error } = await supabase.from<Channel>('channels').insert({
      name: newChannelName,
      description: newChannelDesc,
      created_by: user.id
    });

    if (error) {
      console.error('Error creating channel:', error);
    } else {
      setNewChannelName('');
      setNewChannelDesc('');
      setShowNewChannel(false);
      fetchChannels();
    }
  };

  // ... rest of the existing functions with appropriate type annotations ...

  return (
    <div className="h-screen flex">
      <div className="w-64 bg-gray-800 text-white flex flex-col">
        <div className="p-4 border-b border-gray-700">
          <h1 className="text-xl font-bold">ChatGenius</h1>
        </div>
        
        <div className="flex-1 overflow-y-auto">
          <div className="p-4">
            <div className="flex items-center justify-between mb-2">
              <h2 className="flex items-center text-sm font-semibold">
                <MessageSquare className="w-4 h-4 mr-2" />
                Channels
              </h2>
              <button
                onClick={() => setShowNewChannel(true)}
                className="p-1 hover:bg-gray-700 rounded"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            {showNewChannel && (
              <form onSubmit={createChannel} className="mb-4 space-y-2">
                <input
                  type="text"
                  value={newChannelName}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewChannelName(e.target.value)}
                  placeholder="Channel name"
                  className="w-full px-2 py-1 text-sm bg-gray-700 rounded focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
                <input
                  type="text"
                  value={newChannelDesc}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewChannelDesc(e.target.value)}
                  placeholder="Description (optional)"
                  className="w-full px-2 py-1 text-sm bg-gray-700 rounded focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
                <div className="flex space-x-2">
                  <button
                    type="submit"
                    className="px-2 py-1 text-xs bg-indigo-600 rounded hover:bg-indigo-700"
                  >
                    Create
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowNewChannel(false)}
                    className="px-2 py-1 text-xs bg-gray-700 rounded hover:bg-gray-600"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            )}

            <ul className="space-y-1">
              {channels.map((channel: Channel) => (
                <li
                  key={channel.id}
                  className={`cursor-pointer p-1 rounded hover:bg-gray-700 ${
                    currentChannel?.id === channel.id ? 'bg-gray-700' : ''
                  }`}
                  onClick={() => {
                    setCurrentChannel(channel);
                    fetchMessages(channel.id);
                  }}
                >
                  # {channel.name}
                </li>
              ))}
            </ul>
          </div>

          {/* Rest of the existing JSX ... */}
        </div>
      </div>
    </div>
  );
}