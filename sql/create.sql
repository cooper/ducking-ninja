-- phpMyAdmin SQL Dump
-- version 4.0.10deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jan 08, 2015 at 04:32 PM
-- Server version: 10.0.15-MariaDB-1~trusty-log
-- PHP Version: 5.5.9-1ubuntu4.5

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `numingle`
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
  `reason` text COMMENT 'reason for ban'
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
  `found_stranger` tinyint(1) NOT NULL COMMENT 'true if stranger found',
  `start_time` int(20) NOT NULL COMMENT 'time conversation started',
  `found_time` int(20) NOT NULL COMMENT 'time stranger was found',
  `end_time` int(20) NOT NULL COMMENT 'time conversation ended',
  `question` text COMMENT 'question asked/answered',
  `messages_sent` int(10) NOT NULL COMMENT 'messages sent',
  `messages_received` int(10) NOT NULL COMMENT 'messages received',
  `client_duration` int(10) NOT NULL COMMENT 'client-determined duration',
  `server_duration` int(10) NOT NULL COMMENT 'server-determined duration',
  `fate` tinyint(1) NOT NULL COMMENT 'fate of conversation; 0 = user disconnected, 1 = stranger disconnected'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `convo_events`
--

CREATE TABLE IF NOT EXISTS `convo_events` (
  `id` varchar(32) NOT NULL COMMENT 'numingle conversation ID',
  `event` varchar(64) NOT NULL COMMENT 'the event name',
  `value` text COMMENT 'an optional value',
  `source` varchar(32) NOT NULL COMMENT 'how this conversation was obtained'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Conversation contents';

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
  `popularity` int(10) NOT NULL COMMENT 'popularity number',
  `display_title` varchar(32) NOT NULL COMMENT 'display title',
  `display_subtitle` varchar(64) NOT NULL COMMENT 'display subtitle',
  `style_border_color` varchar(32) NOT NULL COMMENT 'box border color',
  `style_background_color` varchar(32) NOT NULL COMMENT 'box background color',
  `style_background_image` varchar(128) NOT NULL COMMENT 'box background image URL',
  `style_font_size` tinyint(4) NOT NULL COMMENT 'display title font size',
  `style_text_color` varchar(24) NOT NULL COMMENT 'display title and subtitle text color',
  `style_shadow_opacity` float NOT NULL COMMENT 'opacity of text shadows',
  `style_shadow_radius` float NOT NULL COMMENT 'radius of text shadow',
  `style_shadow_offset_x` int(3) NOT NULL COMMENT 'x offset of text shadow',
  `style_shadow_offset_y` int(3) NOT NULL COMMENT 'y offset of text shadow',
  `create_time` int(32) NOT NULL COMMENT 'UNIX timestamp at which the group was created'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Trend group information';

-- --------------------------------------------------------

--
-- Table structure for table `group_relations`
--

CREATE TABLE IF NOT EXISTS `group_relations` (
  `group1` varchar(32) NOT NULL COMMENT 'first group',
  `group2` varchar(32) NOT NULL COMMENT 'second group',
  `interest` varchar(32) NOT NULL COMMENT 'interest',
  `time` int(10) NOT NULL COMMENT 'relation create time'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Group interest relations';

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
-- Table structure for table `logs`
--

CREATE TABLE IF NOT EXISTS `logs` (
  `id` varchar(32) NOT NULL COMMENT 'numingle conversation ID',
  `server` varchar(64) NOT NULL COMMENT 'numingle server',
  `ip` varchar(40) NOT NULL COMMENT 'log device IP address',
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID',
  `time` int(20) NOT NULL COMMENT 'time log submitted'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='conversation log submissions';

-- --------------------------------------------------------

--
-- Table structure for table `registry`
--

CREATE TABLE IF NOT EXISTS `registry` (
  `license_key` varchar(32) NOT NULL COMMENT 'current license key of device',
  `registration_key` varchar(64) NOT NULL COMMENT 'key generated to register device',
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID',
  `ip` varchar(40) NOT NULL COMMENT 'IP addresses at which device was registered',
  `server` varchar(64) NOT NULL COMMENT 'server on which the device was registered',
  `model` varchar(64) NOT NULL COMMENT 'device model identifier',
  `common_name` varchar(64) NOT NULL COMMENT 'device common name',
  `short_version` varchar(24) NOT NULL COMMENT 'app bundle short version',
  `bundle_version_key` varchar(24) NOT NULL COMMENT 'app bundle version key',
  `time` int(32) NOT NULL COMMENT 'time at which device was registered',
  UNIQUE KEY `unique_global_device_id` (`unique_global_device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Device license keys';

-- --------------------------------------------------------

--
-- Table structure for table `reports`
--

CREATE TABLE IF NOT EXISTS `reports` (
  `id` varchar(32) NOT NULL COMMENT 'numingle conversation ID',
  `server` varchar(64) NOT NULL COMMENT 'numingle server',
  `ip` varchar(40) NOT NULL COMMENT 'reporter IP address',
  `unique_device_id` varchar(64) NOT NULL COMMENT 'unique device ID',
  `unique_global_device_id` varchar(64) NOT NULL COMMENT 'unique global device ID',
  `reason` text COMMENT 'report comments',
  `time` int(20) NOT NULL COMMENT 'time reported'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Inappropriate conversation reports';

-- --------------------------------------------------------

--
-- Table structure for table `servers`
--

CREATE TABLE IF NOT EXISTS `servers` (
  `name` varchar(50) NOT NULL,
  `index` int(11) NOT NULL,
  `enabled` tinyint(1) NOT NULL COMMENT 'server enabled',
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Client server list';

-- --------------------------------------------------------

--
-- Table structure for table `stats_peak`
--

CREATE TABLE IF NOT EXISTS `stats_peak` (
  `count` int(32) NOT NULL COMMENT 'peak number of users online',
  `time` int(32) NOT NULL COMMENT 'time at which peak user count was submitted',
  `num` int(10) NOT NULL COMMENT 'peak user count record identifier number',
  UNIQUE KEY `num` (`num`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Peak user count statistic';

-- --------------------------------------------------------

--
-- Table structure for table `templates`
--

CREATE TABLE IF NOT EXISTS `templates` (
  `name` varchar(32) NOT NULL COMMENT 'template name',
  `content` text COMMENT 'template content source',
  `time_added` int(20) NOT NULL COMMENT 'time added'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='HTML templates';

-- --------------------------------------------------------

--
-- Table structure for table `welcome`
--

CREATE TABLE IF NOT EXISTS `welcome` (
  `message` varchar(32) NOT NULL COMMENT 'welcome message',
  `time` int(32) NOT NULL COMMENT 'time added'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='welcome messages';

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
