package com.have.controller;

import com.github.benmanes.caffeine.cache.Cache;
import com.have.pojo.TextMessage;
import com.have.util.WechatMessageUtils;
import io.github.asleepyfish.exception.ChatGPTException;
import io.github.asleepyfish.util.OpenAiUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * @author Chen haoyu
 * @description
 * @date 2023/2/17
 */
@RestController
@Slf4j
public class MainController {
    private static final String FROM_USER_NAME = "FromUserName";
    private static final String TO_USER_NAME = "ToUserName";
    private static final String CONTENT = "Content";

    @Autowired
    private Cache<String, String> cache;

    @GetMapping("/callback")
    public void callback(String signature, String timestamp, String nonce, String echostr, HttpServletResponse response) throws IOException {
        PrintWriter out = response.getWriter();
        out.write(echostr);
    }

    @PostMapping("/callback")
    public void conversion(HttpServletRequest request, HttpServletResponse response) throws Exception {
        Map<String, String> requestMap = WechatMessageUtils.parseXml(request);
        String wechatId = requestMap.get(FROM_USER_NAME);
        String gongzhonghaoId = requestMap.get(TO_USER_NAME);
        String content = requestMap.get(CONTENT);
        TextMessage textMessage = WechatMessageUtils.getDefaultTextMessage(wechatId, gongzhonghaoId);
        String result = cache.get(wechatId + ":" + content.hashCode(), key -> "");
        if (StringUtils.isEmpty(result)) {
            CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
                log.info("receive: {}", content);
                List<String> completion;
                try {
                    completion = OpenAiUtils.createCompletion(content);
                } catch (ChatGPTException e) {
                    log.error("ChatGPT请求失败");
                    return "非常抱歉，请求失败辣，请稍后重试一下!";
                }
                StringBuilder sb = new StringBuilder();
                for (String s : completion) {
                    sb.append(s);
                    sb.append("\n");
                }
                textMessage.setContent(sb.toString());
                log.info("chatGPT reply:" + content + ":" + sb);
                cache.put(wechatId + ":" + content.hashCode(), sb.toString());
                return sb.toString();
            });
            Thread.sleep(2000L);
            if (future.isDone() && !StringUtils.isEmpty(future.get())) {
                result = future.get();
            } else {
                result = "请稍等一下重发一次,chatGPT正在生成您的回复。";
            }
        }
        log.info("result: {}", result);
        textMessage.setContent(result);
        String ret = WechatMessageUtils.textMessageToXml(textMessage);
        response.setCharacterEncoding("UTF-8");
        PrintWriter out = response.getWriter();
        out.write(ret);
    }


//    @GetMapping("/local")
//    public String conversion(@RequestParam String message) throws Exception {
//        log.info("receive: {}", message);
//        List<String> completion = OpenAiUtils.createCompletion(message);
//        StringBuilder sb = new StringBuilder();
//        for (String s : completion) {
//            sb.append(s);
//            sb.append("\n");
//        }
//        log.info("result: {}", sb);
//        return sb.toString();
//    }

//    @GetMapping("/callback")
//    public void callback(String signature, String timestamp, String nonce, String echostr, HttpServletResponse response) throws IOException {
//        PrintWriter out = response.getWriter();
//        out.write(echostr);
//    }
//
//    @PostMapping("/callback")
//    public void conversion(HttpServletRequest request, HttpServletResponse response) throws Exception {
//        Map<String, String> requestMap = WechatMessageUtils.parseXml(request);
//        String wechatId = requestMap.get(FROM_USER_NAME);
//        String gongzhonghaoId = requestMap.get(TO_USER_NAME);
//        String content = requestMap.get(CONTENT);
//        TextMessage textMessage = WechatMessageUtils.getDefaultTextMessage(wechatId, gongzhonghaoId);
//        textMessage.setContent("公众号先下线咯～后面再服务大爷～～");
//        String ret = WechatMessageUtils.textMessageToXml(textMessage);
//        response.setCharacterEncoding("UTF-8");
//        PrintWriter out = response.getWriter();
//        out.write(ret);
//    }


    @GetMapping("/checkpreload")
    public String checkpreload() {
        return "success";
    }
}
