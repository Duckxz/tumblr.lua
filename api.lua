local json = require [[rapidjson]]
local https = require [[ssl.https]]
local base_url = "https://api.tumblr.com/v2"

Tumblr       = {}
Avatar       = {}
SingleAvatar = {}
Blog         = {}
Theme        = {}
SinglePost   = {}
Post         = {}

local valid_post_types = {
   "text",
   "chat",
   "audio",
   "photo",
   "video",
   "link",
   "answer",
   "quote",
}

local function isValidPostType(type)
  for i,v in pairs(valid_post_types) do
    if type == v then
      return true
    end
  end
  return false
end

__single_avatar = {
  __index = nil,
  __call = function(self,avatar)
    if not avatar then
      error("invalid avatar data passed")
    end
    local __instance__ = {
      url = avatar.url,
      width = avatar.width,
      height = avatar.height,
    }
    return __instance__
  end,
}
setmetatable(SingleAvatar,__single_avatar)



__avatar = {
  __index = nil,
  __call = function(self,avatar,multiple)
    local __instance__ = {
      multiple = false,
    }
    if multiple then
      __instance__.multiple = true
      __instance__.avatars = {}
      for i = 1,#avatar do
        table.insert(__instance__.avatars,SingleAvatar(avatar[i]))
      end
    else
      __instance__.url = avatar[1].url
      __instance__.width = avatar[1].width
      __instance__.height = avatar[1].height

      function __instance__:getAvatar(index)
        if not index or index <= 0 then
          error("invalid index given")
        end
        if self.multiple then
          return SingleAvatar(self.avatars[index])
        else
          return SingleAvatar(self) -- return one regardless
        end
      end
    end
    return __instance__
  end,
}
setmetatable(Avatar,__avatar)


__theme = {
  __index = nil,
  __call = function(self,theme)
    if not theme then
      error("invalid theme data passed")
    end
    local __instance__ = {
      avatar_shape = theme.avatar_shape,
      background_color = theme.background_color,
      body_font = theme.body_font,
      header_bounds = theme.header_bounds,
      header_image = theme.header_image,
      header_image_focused = theme.header_image_focused,
      header_image_poster = theme.header_image_poster,
      header_image_scaled = theme.header_image_scaled,
      header_stretch = theme.header_stretch,
      link_color = theme.link_color,
      show_avatar = theme.show_avatar,
      show_description = theme.show_description,
      show_title = theme.show_title,
      title_color = theme.title_color,
      title_font = theme.title_font,
      title_font_weight = theme.title_font_weight,
    }
    return __instance__
  end
}
setmetatable(Theme,__theme)


__blog = {
  __index = nil,
  __call = function(self,blog)
    if not blog then
      error("no blog data passed")
    end
    local __instance__ = {
      ask = blog.ask,
      ask_anon = blog.ask_anon,
      ask_page_title = blog.ask_page_title,
      avatar = Avatar(blog.avatar,(#blog.avatar > 1 and true or false)),
      can_chat = blog.can_chat,
      can_subscribe = blog.can_subscribe,
      description = blog.description,
      is_nsfw = blog.is_nsfw,
      name = blog.name,
      posts = blog.posts,
      share_likes = blog.share_likes,
      submission_page_title = blog.submission_page_title,
      subscribed = blog.subscribed,
      theme = Theme(blog.theme), -- will be a Theme object later
      title = blog.title,
      total_posts = blog.total_posts,
      updated = blog.updated,
      url = blog.url,
      uuid = blog.uuid,
      is_optout_ads = blog.is_optout_ads,
    }
    return __instance__
  end,
}
setmetatable(Blog,__blog)


__single_post  = {
  __index = nil,
  __call = function(self,post)
    if not post then
      print(post)
      error("invalid post data passed")
    end
    local __instance__ = {
      blog_name = post.blog_name,
      id = post.id,
      id_string = post.id_string,
      post_url = post.post_url,
      type = post.type,
      timestamp = post.timestamp,
      date = post.date,
      format = post.format,
      reblog_key = post.reblog_key,
      tags = post.tags,
      bookmarklet = post.bookmarklet,
      mobile = post.mobile,
      source_url = post.source_url,
      source_title = post.source_title,
      liked = post.liked,
      state = post.state,
      total_posts = 1,
    }
    return __instance__
  end
}
setmetatable(SinglePost,__single_post)

__post = {
  __index = nil,
  __call = function(self,post)
    if not post then
      error("invalid post data passed")
    end
    local __instance__ = {}
    if post.total_posts > 1 then
      __instance__.posts = {}
      __instance__.total_posts = post.total_posts
      for i = 1,#post.posts do
        table.insert(__instance__.posts,SinglePost(post.posts[i]))
      end
    else
      __instance__ = SinglePost(post.posts[1])
  end
  return __instance__
end
}
setmetatable(Post,__post)

__tumblr = {
  __index = nil,
  __call = function(self,api_key,own_blog_identifier)
    if not api_key or api_key == " " or api_key == "" then
      error("invalid api key passed")
    end
    local __instance__ = {
      api_key = api_key,
      own_blog_identifier = own_blog_identifier,
    }

    function __instance__:userInfo(blog_identifier)
      if (not blog_identifier or blog_identifier == " " or blog_identifier == "") and (not self.own_blog_identifier or self.own_blog_identifier == "" or self.own_blog_identifier == " ") then
        error("no blog identifier nor own blog identifier passed for Tumblr:userInfo() to use")
      else
        local path = "/blog/"..(not blog_identifier and self.own_blog_identifier or blog_identifier).."/info?api_key="..self.api_key
        local response = {https.request(base_url..path)}
        local decoded = json.decode(response[1])
        if response[2] ~= 200 then
          return "blog might be NSFW or non-existent",response[2],decoded.meta.msg
        else
          return Blog(decoded.response.blog)
        end
      end
    end

    function __instance__:blogPosts(blog_identifier,filter_type,id,tag,limit,offset,reblog_info,notes_info,before)
      if not blog_identifier and not self.own_blog_identifier or self.own_blog_identifier == "" or self.own_blog_identifier == " " then
        error("no blog identifier nor own blog identifier passed for Tumblr:blogPosts()")
      elseif filter_type and not isValidPostType(filter_type) then
        error("invalid type filter specified")
      elseif tag and tag == " " or tag == "" then
        error("invalid tag data specified")
      elseif limit and (limit <= 0 or limit > 20) then
        error("invalid limit specified, must be 1-20")
      elseif offset and offset < 0 then
        error("offset must be positive")
      else
        local path = "/blog/"..(blog_identifier and blog_identifier or self.own_blog_identifier).."/posts"..(filter_type and '/'..filter_type or "").."?api_key="..self.api_key..(id and "&id="..tostring(id) or "")..(tag and "&tag="..tag or "")..(limit and "&limit="..tostring(limit) or "")..(offset and "&offset="..tostring(offset) or "")..(reblog_info and "&reblog_info="..tostring(true) or "")..(notes_info and "&notes_info="..tostring(true) or "")..(before and "&before="..tostring(before) or "")
        local response = {https.request(base_url..path)}
        local decoded = json.decode(response[1])
        if response[2] ~= 200 then
          return "blog could be NSFW or non existent",response[2],decoded.meta.msg
        else
          return Post(decoded.response)
        end
      end
    end

    function __instance__:blogLikes(blog_identifier,limit,offset,before,after)
      if not blog_identifier and not self.own_blog_identifier or self.own_blog_identifier == "" or self.own_blog_identifier == " " then
        error("no blog identifier nor own blog identifier passed for Tumblr:blogPosts()")
      elseif limit and (limit <= 0 or limit > 20) then
        error("limit must be 1-20")
      elseif offset and (offset < 0) then
        error("offset must be a positive number")
      elseif before and before < 0 then
        error("date before must be a positive number")
      elseif after and after < 0 then
        error("date after must be a positive")
      else
        local path = "/blog/"..(blog_identifier and blog_identifier or self.own_blog_identifier).."/likes?api_key="..self.api_key..(limit and "&limit="..tostring(limit) or "")..(offset and "&offset="..tostring(offset) or "")..(before and "&before="..tostring(before) or "")..(after and "&after="..tostring(after) or "")
        local response = {https.request(base_url..path)}
        local decoded = json.decode(response[1])
        if response[2] ~= 200 then
          return "blog has likes privated",response[2],decoded.meta.msg
        else
          decoded.response.total_posts = #decoded.response.liked_posts
          decoded.response.posts = decoded.response.liked_posts
          local likes = Post(decoded.response)
          likes.liked_count = decoded.response.liked_count
          return likes
        end
      end
    end

    function __instance__:taggedPosts(tag,before,limit)
      if not tag or tag == "" or tag == " " then
        error("invalid tag passed")
      elseif before and before < 0 then
        error("before must be a positive number")
      elseif limit and (limit <= 0 or limit > 20) then
        erorr("limit must be 1-20")
      else
        local path = "/tagged".."?api_key="..self.api_key..(tag and "&tag="..tag or "")..(before and "&before="..tostring(before) or "")..(limit and "&limit="..tostring(limit) or "")
        local response = {https.request(base_url..path)}
        local decoded = json.decode(response[1])
        if response[2] ~= 200 then
          return "unknown error",response[2],decoded.meta.msg
        else
          local obj = {
            total_posts = #decoded.response,
            posts = decoded.response
          }
          return Post(obj)
        end
      end
    end

    return __instance__
  end,
}
setmetatable(Tumblr,__tumblr)
