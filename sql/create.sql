SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

--
-- Database: `duckingninja`
--

-- --------------------------------------------------------

--
-- Table structure for table `bans`
--

CREATE TABLE IF NOT EXISTS `bans` (
  `banned` tinyint(1) NOT NULL COMMENT 'boolean if ban is active',
  `ip` varchar(40) NOT NULL COMMENT 'IP address',
  `time` int(32) NOT NULL COMMENT 'UNIX timestamp when ban created',
  `license_key` varchar(64) NOT NULL COMMENT 'license key banned (optional)',
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID (optional)',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID (optional)',
  `reason` text NOT NULL COMMENT 'reason for ban'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `conversations`
--

CREATE TABLE IF NOT EXISTS `conversations` (
  `id` varchar(32) NOT NULL COMMENT 'numingle conversation ID',
  `omegle_id` varchar(128) NOT NULL COMMENT 'omegle session ID',
  `session_type` varchar(32) NOT NULL COMMENT 'string session type',
  `server` varchar(64) NOT NULL COMMENT 'numingle server',
  `omegle_server` varchar(64) NOT NULL COMMENT 'omegle server',
  `ip` varchar(40) NOT NULL COMMENT 'device IP address',
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID',
  `found_stranger` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'true if stranger found',
  `start_time` int(20) NOT NULL COMMENT 'time conversation started',
  `found_time` int(20) NOT NULL COMMENT 'time stranger was found',
  `end_time` int(20) NOT NULL COMMENT 'time conversation ended',
  `question` text NOT NULL COMMENT 'question asked/answered',
  `messages_sent` int(10) NOT NULL COMMENT 'messages sent',
  `messages_received` int(10) NOT NULL COMMENT 'messages received',
  `client_duration` int(10) NOT NULL COMMENT 'client-determined duration',
  `server_duration` int(10) NOT NULL COMMENT 'server-determined duration',
  `fate` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'fate of conversation; 0 = user disconnected, 1 = stranger disconnected'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `convo_interests`
--

CREATE TABLE IF NOT EXISTS `convo_interests` (
  `id` varchar(32) NOT NULL COMMENT 'numingle conversation ID',
  `group_supplied` varchar(32) NOT NULL COMMENT 'group name supplied',
  `interest_supplied` varchar(32) NOT NULL COMMENT 'standalone interest supplied',
  `interest_matched` varchar(32) NOT NULL COMMENT 'interest matched with stranger'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Interests and groups of conversations';

-- --------------------------------------------------------

--
-- Table structure for table `groups`
--

CREATE TABLE IF NOT EXISTS `groups` (
  `name` varchar(32) NOT NULL COMMENT 'name of group',
  `popularity` int(10) NOT NULL DEFAULT '0' COMMENT 'popularity number',
  `display_title` varchar(32) NOT NULL COMMENT 'display title',
  `display_subtitle` varchar(64) NOT NULL COMMENT 'display subtitle',
  `style_border_color` varchar(32) NOT NULL COMMENT 'box border color',
  `style_background_color` varchar(32) NOT NULL COMMENT 'box background color',
  `style_background_image` varchar(128) NOT NULL COMMENT 'box background image URL',
  `style_font_size` tinyint(4) NOT NULL COMMENT 'display title font size',
  `style_text_color` varchar(24) NOT NULL COMMENT 'display title and subtitle text color',
  `create_time` int(32) NOT NULL COMMENT 'UNIX timestamp at which the group was created'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Trend group information';

-- --------------------------------------------------------

--
-- Table structure for table `interests`
--

CREATE TABLE IF NOT EXISTS `interests` (
  `group` varchar(32) NOT NULL COMMENT 'name of group',
  `interest` varchar(64) NOT NULL COMMENT 'interest name (no hashtag)',
  `time` int(32) NOT NULL COMMENT 'time at which interest was added to group'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Interests in trend groups';

-- --------------------------------------------------------

--
-- Table structure for table `registry`
--

CREATE TABLE IF NOT EXISTS `registry` (
  `license_key` varchar(32) NOT NULL COMMENT 'current license key of device',
  `registration_key` varchar(64) NOT NULL,
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID',
  `ip` varchar(40) NOT NULL COMMENT 'IP addresses at which device was registered',
  `server` varchar(64) NOT NULL COMMENT 'server on which the device was registered',
  `time` int(32) NOT NULL COMMENT 'time at which device was registered'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Device license keys';

-- --------------------------------------------------------

--
-- Table structure for table `servers`
--

CREATE TABLE IF NOT EXISTS `servers` (
  `name` varchar(50) NOT NULL,
  `index` int(11) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'server enabled'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Client server list';

-- --------------------------------------------------------

--
-- Table structure for table `statistics`
--

CREATE TABLE IF NOT EXISTS `statistics` (
  `peak_user_count` int(32) NOT NULL DEFAULT '0' COMMENT 'peak number of users online',
  `peak_user_count_timestamp` int(32) NOT NULL DEFAULT '0' COMMENT 'time at which peak user count was submitted',
  `peak_user_count_num` int(10) NOT NULL DEFAULT '-1' COMMENT 'peak user count record identifier number'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `welcome`
--

CREATE TABLE IF NOT EXISTS `welcome` (
  `message` varchar(32) NOT NULL COMMENT 'welcome message',
  `time` int(32) NOT NULL COMMENT 'time added'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='welcome messages';

